// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { GeneralConfig } from "src/interfaces/IMultiVaultCore.sol";

contract MockAtomWallet {
    address public owner;
    bool public isClaimed;
    uint256 public claimCount;

    constructor(address initialOwner) {
        owner = initialOwner;
    }

    function completeClaim(address newOwner) external {
        owner = newOwner;
        isClaimed = true;
        unchecked {
            ++claimCount;
        }
    }
}

contract MockMultiVault {
    bytes32 internal constant ATOM_SALT = keccak256("ATOM_SALT");

    address public configAdmin;

    mapping(bytes32 atomId => bool exists) public isAtom;
    mapping(bytes32 atomId => bytes atomData) internal _atoms;
    mapping(bytes32 atomId => address atomWallet) public atomWallets;
    mapping(bytes32 atomId => address creator) public atomCreators;
    mapping(bytes32 atomId => uint48 createdAt) public atomCreatedAt;
    mapping(address atomWallet => uint256 accumulatedFees) public accumulatedAtomWalletDepositFees;

    function atom(bytes32 atomId) external view returns (bytes memory) {
        return _atoms[atomId];
    }

    function calculateAtomId(bytes memory data) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(ATOM_SALT, keccak256(data)));
    }

    function computeAtomWalletAddr(bytes32 atomId) external view returns (address) {
        return atomWallets[atomId];
    }

    function getAtomCreator(bytes32 atomId) external view returns (address) {
        return atomCreators[atomId];
    }

    function getAtomCreatedAt(bytes32 atomId) external view returns (uint48) {
        return atomCreatedAt[atomId];
    }

    function setAtom(
        bytes32 atomId,
        bytes memory data,
        address wallet,
        address creator,
        uint48 createdTimestamp
    )
        external
    {
        isAtom[atomId] = true;
        _atoms[atomId] = data;
        atomWallets[atomId] = wallet;
        atomCreators[atomId] = creator;
        atomCreatedAt[atomId] = createdTimestamp;
    }

    function setAccumulatedFees(address wallet, uint256 amount) external {
        accumulatedAtomWalletDepositFees[wallet] = amount;
    }

    function setConfigAdmin(address _admin) external {
        configAdmin = _admin;
    }

    function getGeneralConfig() external view returns (GeneralConfig memory) {
        return GeneralConfig({
            admin: configAdmin,
            protocolMultisig: address(0),
            feeDenominator: 10_000,
            trustBonding: address(0),
            minDeposit: 0,
            minShare: 0,
            atomDataMaxLength: 0,
            feeThreshold: 0
        });
    }
}

contract AtomWardenTest is Test {
    bytes32 internal constant CLAIM_AUTHORIZATION_TYPEHASH = keccak256(
        "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
    );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    AtomWarden internal atomWarden;
    TransparentUpgradeableProxy internal atomWardenProxy;
    MockMultiVault internal multiVault;

    address internal admin;
    address internal operator;
    address internal claimant;
    address internal creator;
    uint256 internal signerPrivateKey;
    address internal signer;

    uint256 internal constant DEFAULT_CLAIM_WINDOW = 7 days;
    uint256 internal constant DEFAULT_MIN_FEE_THRESHOLD = 0.25 ether;
    uint256 internal constant DEFAULT_SIGNATURE_THRESHOLD = 1;
    /// @dev Permissive enough that existing auth-building tests (`validAfter = now - 1`,
    ///      `validUntil = now + 1 days`) pass; targeted cap tests override via setters.
    uint48 internal constant DEFAULT_MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant DEFAULT_MAX_VALID_UNTIL = uint48(7 days);

    function setUp() external {
        admin = makeAddr("admin");
        operator = makeAddr("operator");
        claimant = makeAddr("claimant");
        creator = makeAddr("creator");
        signerPrivateKey = 0xBEEF;
        signer = vm.addr(signerPrivateKey);

        multiVault = new MockMultiVault();
        multiVault.setConfigAdmin(admin);

        AtomWarden atomWardenImplementation = new AtomWarden();
        atomWardenProxy = new TransparentUpgradeableProxy(address(atomWardenImplementation), admin, "");
        atomWarden = AtomWarden(address(atomWardenProxy));
        atomWarden.initialize(
            admin,
            address(multiVault),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );

        bytes32 operatorRole = atomWarden.OPERATOR_ROLE();
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.prank(admin);
        atomWarden.grantRole(operatorRole, operator);
        vm.prank(admin);
        atomWarden.grantRole(signerRole, signer);
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_initialize_setsRolesAndConfig() external view {
        assertEq(atomWarden.multiVault(), address(multiVault));
        assertEq(atomWarden.claimWindow(), DEFAULT_CLAIM_WINDOW);
        assertEq(atomWarden.minFeeThreshold(), DEFAULT_MIN_FEE_THRESHOLD);
        assertTrue(atomWarden.hasRole(atomWarden.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(atomWarden.hasRole(atomWarden.OPERATOR_ROLE(), admin));
        assertTrue(atomWarden.hasRole(atomWarden.OPERATOR_ROLE(), operator));
        assertTrue(atomWarden.hasRole(atomWarden.SIGNER_ROLE(), signer));
    }

    function test_initialize_revertsOnZeroAdmin() external {
        AtomWarden implementation = new AtomWarden();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), admin, "");
        AtomWarden freshWarden = AtomWarden(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidAddress.selector));
        freshWarden.initialize(
            address(0),
            address(multiVault),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
    }

    function test_initialize_revertsOnZeroMultiVault() external {
        AtomWarden implementation = new AtomWarden();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), admin, "");
        AtomWarden freshWarden = AtomWarden(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidAddress.selector));
        freshWarden.initialize(
            admin,
            address(0),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
    }

    function test_initialize_revertsOnZeroSignatureThreshold() external {
        AtomWarden implementation = new AtomWarden();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), admin, "");
        AtomWarden freshWarden = AtomWarden(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidThreshold.selector));
        freshWarden.initialize(
            admin,
            address(multiVault),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            0,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
    }

    function test_initialize_setsCustomSignatureThreshold() external {
        AtomWarden implementation = new AtomWarden();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(implementation), admin, "");
        AtomWarden freshWarden = AtomWarden(address(proxy));

        freshWarden.initialize(
            admin,
            address(multiVault),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            5,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
        assertEq(freshWarden.signatureThreshold(), 5);
        // signerCount stays 0 until SIGNER_ROLE grants land; claims revert until then.
        assertEq(freshWarden.signerCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            REINITIALIZE
    //////////////////////////////////////////////////////////////*/

    function test_reinitialize_setsConfigAtomicallyAndBootstrapsRoles() external {
        // Deploy a fresh proxy at initializer version 1 (simulating the pre-upgrade state)
        MockMultiVault freshMultiVault = new MockMultiVault();
        freshMultiVault.setConfigAdmin(admin);

        AtomWarden freshImpl = new AtomWarden();
        TransparentUpgradeableProxy freshProxy =
            new TransparentUpgradeableProxy(address(freshImpl), makeAddr("proxy-admin"), "");
        AtomWarden freshWarden = AtomWarden(address(freshProxy));

        freshWarden.initialize(
            admin,
            address(freshMultiVault),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );

        uint256 newClaimWindow = 21 days;
        uint256 newMinFeeThreshold = 1.5 ether;
        uint256 newSignatureThreshold = 3;
        uint48 newMaxValidAfter = uint48(30 minutes);
        uint48 newMaxValidUntil = uint48(3 days);

        vm.prank(admin);
        freshWarden.reinitialize(
            newClaimWindow, newMinFeeThreshold, newSignatureThreshold, newMaxValidAfter, newMaxValidUntil
        );

        assertTrue(freshWarden.hasRole(freshWarden.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(freshWarden.hasRole(freshWarden.OPERATOR_ROLE(), admin));
        assertEq(freshWarden.claimWindow(), newClaimWindow);
        assertEq(freshWarden.minFeeThreshold(), newMinFeeThreshold);
        assertEq(freshWarden.signatureThreshold(), newSignatureThreshold);
        assertEq(freshWarden.maxValidAfter(), newMaxValidAfter);
        assertEq(freshWarden.maxValidUntil(), newMaxValidUntil);
        assertFalse(freshWarden.paused());
    }

    function test_reinitialize_revertsForNonAdmin() external {
        AtomWarden freshWarden = _freshUnreinitializedWarden();

        vm.prank(makeAddr("arbitrary-caller"));
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_UnauthorizedReinitializer.selector));
        freshWarden.reinitialize(
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
    }

    function test_reinitialize_revertsOnZeroSignatureThreshold() external {
        AtomWarden freshWarden = _freshUnreinitializedWarden();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidThreshold.selector));
        freshWarden.reinitialize(
            DEFAULT_CLAIM_WINDOW, DEFAULT_MIN_FEE_THRESHOLD, 0, DEFAULT_MAX_VALID_AFTER, DEFAULT_MAX_VALID_UNTIL
        );
    }

    function test_reinitialize_revertsWhenCalledTwice() external {
        AtomWarden freshWarden = _freshUnreinitializedWarden();

        vm.prank(admin);
        freshWarden.reinitialize(
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        freshWarden.reinitialize(
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ADDRESS SELF-CLAIM
    //////////////////////////////////////////////////////////////*/

    function test_claimOwnershipOverLowercaseAddressAtom_successful() external {
        bytes32 atomId = _setAddressAtom(claimant, false, false);

        vm.prank(claimant);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        MockAtomWallet wallet = MockAtomWallet(multiVault.atomWallets(atomId));
        assertEq(wallet.owner(), claimant);
        assertTrue(wallet.isClaimed());
    }

    function test_claimOwnershipOverChecksumAddressAtom_successful() external {
        bytes32 atomId = _setAddressAtom(claimant, false, true);

        vm.prank(claimant);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        MockAtomWallet wallet = MockAtomWallet(multiVault.atomWallets(atomId));
        assertEq(wallet.owner(), claimant);
        assertTrue(wallet.isClaimed());
    }

    function test_claimOwnershipOverAddressAtom_revertsOnMismatchedAtomId() external {
        bytes32 atomId = _setAtom("not-the-caller-address", claimant, false, address(0), 0);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ClaimOwnershipFailed.selector));
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    function test_claimOwnershipOverAddressAtom_revertsOnAlreadyClaimed() external {
        bytes32 atomId = _setAddressAtom(claimant, true, false);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AlreadyClaimed.selector));
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    /*//////////////////////////////////////////////////////////////
                            SIGNED CLAIMS
    //////////////////////////////////////////////////////////////*/

    function test_claimWithAuthorization_successful() external {
        bytes32 atomId = _setAtom("signed-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: 0,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, signature);

        MockAtomWallet wallet = MockAtomWallet(multiVault.atomWallets(atomId));
        assertEq(wallet.owner(), claimant);
        assertEq(atomWarden.claimNonces(claimant), 1);
    }

    function test_claimWithAuthorization_revertsOnUnauthorizedClaimant() external {
        bytes32 atomId = _setAtom("signed-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: 0,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(makeAddr("wrong-claimant"));
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_UnauthorizedClaimant.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_revertsOnInvalidNonce() external {
        bytes32 atomId = _setAtom("signed-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: 1,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidNonce.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_revertsOnExpiredAuthorization() external {
        vm.warp(3 days);
        bytes32 atomId = _setAtom("signed-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: 0,
            validAfter: uint48(block.timestamp - 2 days),
            validUntil: uint48(block.timestamp - 1 days)
        });

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidTimeWindow.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_revertsOnInvalidSignature() external {
        bytes32 atomId = _setAtom("signed-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: 0,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory signature = _signAuthorization(authorization, 0xCAFE);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_revertsOnReplay() external {
        bytes32 atomId = _setAtom("replay-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: 0,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        // First claim succeeds
        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, signature);
        assertEq(atomWarden.claimNonces(claimant), 1);

        // Replay with same authorization reverts (wallet already claimed)
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AlreadyClaimed.selector));
        atomWarden.claimWithAuthorization(authorization, signature);

        // Replay against a different unclaimed wallet with stale nonce also reverts
        bytes32 atomId2 = _setAtom("replay-claim-2", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory staleAuthorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId2,
            claimType: 1,
            nonce: 0,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory staleSignature = _signAuthorization(staleAuthorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidNonce.selector));
        atomWarden.claimWithAuthorization(staleAuthorization, staleSignature);
    }

    /*//////////////////////////////////////////////////////////////
                                GRANTS
    //////////////////////////////////////////////////////////////*/

    function test_grantAtomWalletOwnership_successful() external {
        bytes32 atomId = _setAtom("grant", claimant, false, address(0), 0);

        vm.prank(operator);
        atomWarden.grantAtomWalletOwnership(atomId, claimant);

        MockAtomWallet wallet = MockAtomWallet(multiVault.atomWallets(atomId));
        assertEq(wallet.owner(), claimant);
        assertTrue(wallet.isClaimed());
    }

    function test_grantAtomWalletOwnership_revertsOnClaimedWallet() external {
        bytes32 atomId = _setAtom("grant-claimed", claimant, true, address(0), 0);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AlreadyClaimed.selector));
        atomWarden.grantAtomWalletOwnership(atomId, creator);
    }

    function test_batchGrantAtomWalletOwnership_revertsOnLengthMismatch() external {
        bytes32[] memory atomIds = new bytes32[](1);
        atomIds[0] = _setAtom("grant", claimant, false, address(0), 0);
        address[] memory owners = new address[](0);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ArrayLengthMismatch.selector));
        atomWarden.batchGrantAtomWalletOwnership(atomIds, owners);
    }

    function test_batchGrantAtomWalletOwnership_revertsOnBatchTooLarge() external {
        bytes32[] memory atomIds = new bytes32[](151);
        address[] memory owners = new address[](151);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_BatchTooLarge.selector));
        atomWarden.batchGrantAtomWalletOwnership(atomIds, owners);
    }

    function test_batchGrantAtomWalletOwnership_successful() external {
        bytes32[] memory atomIds = new bytes32[](2);
        atomIds[0] = _setAtom("batch-grant-a", claimant, false, address(0), 0);
        atomIds[1] = _setAtom("batch-grant-b", claimant, false, address(0), 0);

        address[] memory owners = new address[](2);
        owners[0] = makeAddr("batch-owner-a");
        owners[1] = makeAddr("batch-owner-b");

        vm.prank(operator);
        atomWarden.batchGrantAtomWalletOwnership(atomIds, owners);

        assertEq(MockAtomWallet(multiVault.atomWallets(atomIds[0])).owner(), owners[0]);
        assertEq(MockAtomWallet(multiVault.atomWallets(atomIds[1])).owner(), owners[1]);
    }

    function test_grantAtomWalletOwnership_revertsOnZeroAddressOwner() external {
        bytes32 atomId = _setAtom("grant-zero", claimant, false, address(0), 0);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidNewOwnerAddress.selector));
        atomWarden.grantAtomWalletOwnership(atomId, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            CREATOR FALLBACK
    //////////////////////////////////////////////////////////////*/

    function test_claimAsCreatorAfterExpiry_successful() external {
        vm.warp(DEFAULT_CLAIM_WINDOW + 1 days);
        bytes32 atomId = _setAtom("creator-fallback", claimant, false, creator, uint48(block.timestamp - 8 days));
        multiVault.setAccumulatedFees(multiVault.atomWallets(atomId), DEFAULT_MIN_FEE_THRESHOLD);

        vm.prank(creator);
        atomWarden.claimAsCreatorAfterExpiry(atomId);

        MockAtomWallet wallet = MockAtomWallet(multiVault.atomWallets(atomId));
        assertEq(wallet.owner(), creator);
    }

    function test_claimAsCreatorAfterExpiry_revertsOnThresholdNotMet() external {
        vm.warp(DEFAULT_CLAIM_WINDOW + 1 days);
        bytes32 atomId = _setAtom("creator-fallback", claimant, false, creator, uint48(block.timestamp - 8 days));
        multiVault.setAccumulatedFees(multiVault.atomWallets(atomId), DEFAULT_MIN_FEE_THRESHOLD - 1);

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_MinFeeThresholdNotMet.selector));
        atomWarden.claimAsCreatorAfterExpiry(atomId);
    }

    function test_claimAsCreatorAfterExpiry_revertsWhenWindowNotElapsed() external {
        bytes32 atomId = _setAtom("creator-fallback", claimant, false, creator, uint48(block.timestamp));
        multiVault.setAccumulatedFees(multiVault.atomWallets(atomId), DEFAULT_MIN_FEE_THRESHOLD);

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ClaimWindowNotElapsed.selector));
        atomWarden.claimAsCreatorAfterExpiry(atomId);
    }

    function test_claimAsCreatorAfterExpiry_revertsOnUnknownCreator() external {
        bytes32 atomId = _setAtom("creator-fallback", claimant, false, address(0), 0);

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_CreatorUnknown.selector));
        atomWarden.claimAsCreatorAfterExpiry(atomId);
    }

    function test_claimAsCreatorAfterExpiry_revertsOnWrongCreator() external {
        bytes32 atomId = _setAtom("creator-fallback", claimant, false, creator, uint48(block.timestamp));

        vm.prank(makeAddr("not-the-creator"));
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_NotAtomCreator.selector));
        atomWarden.claimAsCreatorAfterExpiry(atomId);
    }

    function test_claimAsCreatorAfterExpiry_revertsWhenClaimWindowZero() external {
        vm.prank(admin);
        atomWarden.setClaimWindow(0);

        bytes32 atomId = _setAtom("creator-fallback", claimant, false, creator, uint48(block.timestamp));

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_CreatorClaimDisabled.selector));
        atomWarden.claimAsCreatorAfterExpiry(atomId);
    }

    /*//////////////////////////////////////////////////////////////
                            QUORUM CLAIMS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_bootstrapsSignatureThreshold() external view {
        assertEq(atomWarden.signatureThreshold(), DEFAULT_SIGNATURE_THRESHOLD);
        // signerCount tracks SIGNER_ROLE grants; setUp grants exactly one signer.
        assertEq(atomWarden.signerCount(), 1);
    }

    function test_reinitialize_setsSignatureThresholdFromParam() external {
        AtomWarden freshWarden = _freshUnreinitializedWarden();

        vm.prank(admin);
        freshWarden.reinitialize(
            DEFAULT_CLAIM_WINDOW, DEFAULT_MIN_FEE_THRESHOLD, 4, DEFAULT_MAX_VALID_AFTER, DEFAULT_MAX_VALID_UNTIL
        );

        assertEq(freshWarden.signatureThreshold(), 4);
    }

    function test_reinitialize_leavesSignerCountAtZero() external {
        // No SIGNER_ROLE was granted on a v1 proxy prior to reinitialize, so the
        // consolidated v2 bootstrap must leave signerCount at 0. Admin grants
        // signers post-upgrade and the role-hook overrides drive cardinality.
        AtomWarden freshWarden = _freshUnreinitializedWarden();

        vm.prank(admin);
        freshWarden.reinitialize(
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );

        assertEq(freshWarden.signerCount(), 0);
    }

    function test_claimWithAuthorization_quorumSuccess_twoOfTwo() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        _setSignatureThreshold(2);

        bytes32 atomId = _setAtom("quorum-2of2", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        bytes memory bundle = _buildSortedSignatures(authorization, keys);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, bundle);

        assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed());
        assertEq(atomWarden.claimNonces(claimant), 1);
    }

    function test_claimWithAuthorization_quorumSuccess_twoOfThree() external {
        uint256[] memory grantedKeys = new uint256[](3);
        grantedKeys[0] = 0xA11CE;
        grantedKeys[1] = 0xB0B;
        grantedKeys[2] = 0xC4FE;
        _grantSignerKeys(grantedKeys);
        _setSignatureThreshold(2);

        // Sign with only 2 of the 3 granted signers.
        uint256[] memory signingKeys = new uint256[](2);
        signingKeys[0] = grantedKeys[0];
        signingKeys[1] = grantedKeys[2];

        bytes32 atomId = _setAtom("quorum-2of3", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory bundle = _buildSortedSignatures(authorization, signingKeys);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, bundle);

        assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed());
    }

    function test_claimWithAuthorization_revertsWhenBelowThreshold() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        _setSignatureThreshold(2);

        // Submit only 1 signature against threshold 2.
        uint256[] memory only = new uint256[](1);
        only[0] = keys[0];

        bytes32 atomId = _setAtom("below-threshold", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory bundle = _buildSortedSignatures(authorization, only);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InsufficientSigners.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsOnNonCanonicalOrder() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        _setSignatureThreshold(2);

        bytes32 atomId = _setAtom("non-canonical", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        // Build the bundle in DESCENDING address order (reversed canonical).
        bytes memory bundle = _buildReversedSignatures(authorization, keys);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_NonCanonicalSignerOrder.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsOnDuplicateSigner() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        _setSignatureThreshold(2);

        // Two segments, both signed by the same key — `recovered > previous` fails on
        // the second iteration since equality is rejected by the strictly-ascending
        // ordering rule.
        bytes32 atomId = _setAtom("duplicate", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory sig = _signAuthorization(authorization, keys[0]);
        bytes memory bundle = bytes.concat(sig, sig);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_NonCanonicalSignerOrder.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsOnWrongLength() external {
        bytes32 atomId = _setAtom("wrong-length", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        // 64 bytes is non-zero but not a multiple of 65.
        bytes memory bundle = new bytes(64);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_SignatureLengthInvalid.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsOnEmptySignature() external {
        bytes32 atomId = _setAtom("empty-sig", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_SignatureLengthInvalid.selector));
        atomWarden.claimWithAuthorization(authorization, "");
    }

    function test_claimWithAuthorization_revertsOnBundleExceedingMaxBatchSize() external {
        bytes32 atomId = _setAtom("oversized-bundle", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        // 151 segments (151 * 65 bytes) is a valid multiple of 65 but exceeds MAX_BATCH_SIZE (150).
        // The cap is checked before signature recovery, so the segment contents are irrelevant.
        bytes memory bundle = new bytes((atomWarden.MAX_BATCH_SIZE() + 1) * 65);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_BatchTooLarge.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsOnNonSignerRoleRecovered() external {
        uint256 strangerKey = 0xDECAF;
        // Stranger has a valid keypair but no SIGNER_ROLE grant.

        bytes32 atomId = _setAtom("non-signer", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory bundle = _signAuthorization(authorization, strangerKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsOnInvalidECDSA() external {
        bytes32 atomId = _setAtom("invalid-ecdsa", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        // 65-byte all-zero signature: ecrecover returns address(0) and OZ ECDSA
        // surfaces a non-NoError variant, which `_verifyQuorum` translates into
        // `AtomWarden_InvalidSignature`.
        bytes memory bundle = new bytes(65);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_nonceIncrementsOnce() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        _setSignatureThreshold(2);

        bytes32 atomId = _setAtom("nonce-increments", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory bundle = _buildSortedSignatures(authorization, keys);

        uint256 before = atomWarden.claimNonces(claimant);
        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, bundle);
        assertEq(atomWarden.claimNonces(claimant), before + 1);
    }

    function test_claimWithAuthorization_emitsAugmentedEvent() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        _setSignatureThreshold(2);

        bytes32 atomId = _setAtom("augmented-event", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        // Sort keys by recovered address so we know which is `firstSigner`.
        uint256[] memory sorted = _sortKeysByAddress(keys);
        address firstSigner = vm.addr(sorted[0]);

        bytes memory bundle = _buildSortedSignatures(authorization, keys);

        vm.expectEmit(true, true, true, true);
        emit IAtomWarden.AtomWalletOwnershipClaimedByAuthorization(
            atomId, claimant, firstSigner, authorization.claimType, uint16(2)
        );

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    /*//////////////////////////////////////////////////////////////
                          THRESHOLD SETTER
    //////////////////////////////////////////////////////////////*/

    function test_setSignatureThreshold_revertsOnZero() external {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidThreshold.selector));
        atomWarden.setSignatureThreshold(0);
    }

    function test_setSignatureThreshold_revertsOnAboveSignerCount() external {
        // setUp grants exactly 1 signer; threshold > 1 must revert.
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidThreshold.selector));
        atomWarden.setSignatureThreshold(2);
    }

    function test_setSignatureThreshold_revertsOnNonAdmin() external {
        bytes32 adminRole = atomWarden.DEFAULT_ADMIN_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, operator, adminRole)
        );
        vm.prank(operator);
        atomWarden.setSignatureThreshold(1);
    }

    function test_setSignatureThreshold_emitsEvent() external {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        _grantSignerKeys(keys);
        // signerCount is now 3 (setUp's signer + two new), so threshold ∈ [1,3] is valid.

        vm.expectEmit(true, true, true, true);
        emit IAtomWarden.SignatureThresholdSet(1, 2);

        vm.prank(admin);
        atomWarden.setSignatureThreshold(2);

        assertEq(atomWarden.signatureThreshold(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                          ROLE-HOOK COUNTERS
    //////////////////////////////////////////////////////////////*/

    function test_grantRole_incrementsSignerCount() external {
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        uint256 before = atomWarden.signerCount();
        address newSigner = vm.addr(0xA11CE);

        vm.startPrank(admin);
        atomWarden.grantRole(signerRole, newSigner);
        vm.stopPrank();

        assertEq(atomWarden.signerCount(), before + 1);
    }

    function test_grantRole_idempotentForExistingHolder() external {
        // setUp already granted SIGNER_ROLE to `signer`. Re-granting must be a no-op
        // for signerCount because the parent's `_grantRole` returns false on re-grant.
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        uint256 before = atomWarden.signerCount();

        vm.startPrank(admin);
        atomWarden.grantRole(signerRole, signer);
        vm.stopPrank();

        assertEq(atomWarden.signerCount(), before);
    }

    function test_grantRole_doesNotCountNonSignerRoles() external {
        bytes32 operatorRole = atomWarden.OPERATOR_ROLE();
        uint256 before = atomWarden.signerCount();

        vm.startPrank(admin);
        atomWarden.grantRole(operatorRole, makeAddr("new-operator"));
        vm.stopPrank();

        assertEq(atomWarden.signerCount(), before);
    }

    function test_revokeRole_decrementsSignerCount() external {
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        uint256 before = atomWarden.signerCount();

        vm.startPrank(admin);
        atomWarden.revokeRole(signerRole, signer);
        vm.stopPrank();

        assertEq(atomWarden.signerCount(), before - 1);
    }

    function test_revokeRole_idempotentForNonHolder() external {
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        uint256 before = atomWarden.signerCount();
        address stranger = makeAddr("stranger");

        vm.startPrank(admin);
        atomWarden.revokeRole(signerRole, stranger);
        vm.stopPrank();

        assertEq(atomWarden.signerCount(), before);
    }

    /*//////////////////////////////////////////////////////////////
                          EIP-712 FROZEN VECTOR
    //////////////////////////////////////////////////////////////*/

    function test_eip712Digest_isFrozen() external view {
        // Any drift in the EIP-712 domain (`name`, `version`) or the claim typehash
        // breaks every previously-signed authorization. These hard-coded reference
        // values catch a domain change at compile/run time before it ships.
        bytes32 expectedTypehash = keccak256(
            "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
        );
        assertEq(atomWarden.CLAIM_AUTHORIZATION_TYPEHASH(), expectedTypehash, "claim typehash drifted");

        bytes32 expectedNameHash = keccak256(bytes("AtomWarden"));
        bytes32 expectedVersionHash = keccak256(bytes("2"));

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH, expectedNameHash, expectedVersionHash, block.chainid, address(atomWarden)
            )
        );
        assertEq(_domainSeparator(), expectedDomainSeparator, "domain separator drifted");

        // Frozen authorization → frozen digest. If the formula changes, this test
        // fails immediately (alongside the typehash/domain assertions above).
        IAtomWarden.ClaimAuthorization memory frozen = IAtomWarden.ClaimAuthorization({
            claimant: 0x1234567890AbcdEF1234567890aBcdef12345678,
            atomId: bytes32(uint256(0xCAFEBABE)),
            claimType: 1,
            nonce: 7,
            validAfter: uint48(1_700_000_000),
            validUntil: uint48(1_800_000_000)
        });
        bytes32 expectedStructHash = keccak256(
            abi.encode(
                expectedTypehash,
                frozen.claimant,
                frozen.atomId,
                frozen.claimType,
                frozen.nonce,
                frozen.validAfter,
                frozen.validUntil
            )
        );
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19\x01", expectedDomainSeparator, expectedStructHash));

        // Behavioral cross-check: the contract recovers the signer of `expectedDigest`
        // for the same authorization. If `_hashTypedDataV4` produces anything else,
        // the recovered address would not match.
        bytes memory localBundle;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, expectedDigest);
            localBundle = abi.encodePacked(r, s, v);
        }
        assertEq(_recoverFromBundle(expectedDigest, localBundle), signer, "frozen digest does not recover signer");
    }

    /*//////////////////////////////////////////////////////////////
                          STORAGE-LAYOUT FREEZE
    //////////////////////////////////////////////////////////////*/

    function test_storageLayout_appendsOnly() external {
        // Anchor every slot in AtomWarden's linear storage so a future reorder
        // (or a parent contract migrating away from ERC-7201) shows up as a value
        // mismatch when reading by raw slot index. The four inherited parents
        // (Initializable, AccessControlUpgradeable, EIP712Upgradeable,
        // PausableUpgradeable) all use ERC-7201 namespaced storage in OZ 5.x, so
        // slot 0 onwards belongs entirely to this contract.
        //
        // Owned layout:
        //   slot 0: multiVault (address)
        //   slot 1: claimNonces (mapping base — entries live at keccak hashes)
        //   slot 2: claimWindow (uint256)
        //   slot 3: minFeeThreshold (uint256)
        //   slot 4: signatureThreshold (uint256, v2-appended)
        //   slot 5: signerCount (uint256, v2-appended)
        //   slot 6: maxValidAfter (uint48 low) || maxValidUntil (uint48 next), v3-appended
        //   slot 7+: unused — must remain zero, asserted as the boundary check below.
        address newMultiVault = makeAddr("layout-mv");
        uint48 newMaxValidAfter = uint48(0xAAAAAAAAAAAA); // distinctive 48-bit pattern
        uint48 newMaxValidUntil = uint48(0xBBBBBBBBBBBB);
        vm.prank(admin);
        atomWarden.setMultiVault(newMultiVault);
        vm.prank(admin);
        atomWarden.setClaimWindow(123_456);
        vm.prank(admin);
        atomWarden.setMinFeeThreshold(789_012);
        vm.prank(admin);
        atomWarden.setMaxValidAfter(newMaxValidAfter);
        vm.prank(admin);
        atomWarden.setMaxValidUntil(newMaxValidUntil);
        // Touch the claimNonces mapping so a reorder that demotes slot 1 to a
        // non-mapping field surfaces via the mapping-entry assertion below.
        vm.prank(operator);
        atomWarden.incrementNonce(claimant);

        // slot 0: multiVault (address)
        assertEq(
            address(uint160(uint256(vm.load(address(atomWarden), bytes32(uint256(0)))))),
            newMultiVault,
            "slot 0 must be multiVault"
        );
        // slot 1: claimNonces (mapping base — always zero; entries are at keccak(key, slot))
        assertEq(uint256(vm.load(address(atomWarden), bytes32(uint256(1)))), 0, "slot 1 must be mapping base (zero)");
        // The mapping entry for `claimant` after one increment must equal 1, which
        // doubles as a positive anchor that slot 1 is genuinely the mapping base.
        bytes32 mappingEntrySlot = keccak256(abi.encode(claimant, uint256(1)));
        assertEq(
            uint256(vm.load(address(atomWarden), mappingEntrySlot)),
            1,
            "claimNonces[claimant] must live at keccak(key,1)"
        );
        // slot 2: claimWindow
        assertEq(uint256(vm.load(address(atomWarden), bytes32(uint256(2)))), 123_456, "slot 2 must be claimWindow");
        // slot 3: minFeeThreshold
        assertEq(uint256(vm.load(address(atomWarden), bytes32(uint256(3)))), 789_012, "slot 3 must be minFeeThreshold");
        // slot 4: signatureThreshold (initialized to 1 in setUp)
        assertEq(uint256(vm.load(address(atomWarden), bytes32(uint256(4)))), 1, "slot 4 must be signatureThreshold");
        // slot 5: signerCount (setUp granted exactly one signer)
        assertEq(uint256(vm.load(address(atomWarden), bytes32(uint256(5)))), 1, "slot 5 must be signerCount");
        // slot 6: maxValidAfter (low 6 bytes) || maxValidUntil (next 6 bytes), packed.
        // Solidity stores adjacent <=32-byte fields starting at the low end of the
        // slot in declaration order.
        uint256 slot6 = uint256(vm.load(address(atomWarden), bytes32(uint256(6))));
        assertEq(uint48(slot6), newMaxValidAfter, "slot 6 low 48 bits must be maxValidAfter");
        assertEq(uint48(slot6 >> 48), newMaxValidUntil, "slot 6 next 48 bits must be maxValidUntil");
        // Upper 160 bits of slot 6 must stay zero — otherwise the uint48 packing
        // bled, or an unintended field shares the slot.
        assertEq(slot6 >> 96, 0, "slot 6 upper 160 bits must be zero (packing boundary)");
        // slot 7: boundary check — nothing should land past the declared layout.
        assertEq(uint256(vm.load(address(atomWarden), bytes32(uint256(7)))), 0, "slot 7 must be zero (no spill)");
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_setSignatureThreshold(uint256 newThreshold) external {
        // signerCount in setUp is 1; bound the fuzz to the legal [1, signerCount] range.
        newThreshold = bound(newThreshold, 1, atomWarden.signerCount());

        vm.prank(admin);
        atomWarden.setSignatureThreshold(newThreshold);

        assertEq(atomWarden.signatureThreshold(), newThreshold);
    }

    function testFuzz_claimWithAuthorization_variableN(uint256 nSeed, uint256 keySeed) external {
        // Pick N ∈ [2, 5] signers, all granted SIGNER_ROLE, threshold == N.
        uint256 n = bound(nSeed, 2, 5);
        uint256[] memory keys = _deriveDistinctKeys(keySeed, n);
        _grantSignerKeys(keys);
        _setSignatureThreshold(n);

        bytes32 atomId = _setAtom("fuzz-variable-n", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory bundle = _buildSortedSignatures(authorization, keys);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, bundle);

        assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed());
    }

    function testFuzz_claimWithAuthorization_permutationEqualsCanonicalOrReverts(
        uint256 keySeed,
        uint256 permSeed
    )
        external
    {
        // For any random permutation of N signers concatenated into the bundle,
        // the call must EITHER succeed (permutation already matches canonical
        // ascending order) OR revert with NonCanonicalSignerOrder. No other outcome
        // is acceptable — this nails down the canonical-ordering contract.
        uint256 n = 3;
        uint256[] memory keys = _deriveDistinctKeys(keySeed, n);
        _grantSignerKeys(keys);
        _setSignatureThreshold(n);

        bytes32 atomId = _setAtom("fuzz-permutation", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);

        uint256[] memory permuted = _permuteKeys(keys, permSeed);
        bytes memory bundle = _signInOrder(authorization, permuted);
        bool isCanonical = _isAscendingByAddress(permuted);

        if (isCanonical) {
            vm.prank(claimant);
            atomWarden.claimWithAuthorization(authorization, bundle);
            assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed());
        } else {
            vm.prank(claimant);
            vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_NonCanonicalSignerOrder.selector));
            atomWarden.claimWithAuthorization(authorization, bundle);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function test_incrementNonce_successful() external {
        vm.prank(operator);
        atomWarden.incrementNonce(claimant);

        assertEq(atomWarden.claimNonces(claimant), 1);
    }

    function test_incrementNonce_revertsOnZeroAddress() external {
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidAddress.selector));
        atomWarden.incrementNonce(address(0));
    }

    function test_claimWithAuthorization_revertsOnNonexistentAtom() external {
        bytes32 unknownAtomId = keccak256("does-not-exist");
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(unknownAtomId, 0);
        bytes memory bundle = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AtomIdDoesNotExist.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_claimWithAuthorization_revertsWhenWalletNotDeployed() external {
        // Atom exists but the wallet placeholder has no bytecode — exercises the
        // `code.length == 0` guard inside `_getAtomWallet`.
        bytes32 atomId = multiVault.calculateAtomId(bytes("undeployed-wallet"));
        multiVault.setAtom(atomId, bytes("undeployed-wallet"), makeAddr("not-a-contract"), address(0), 0);

        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory bundle = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AtomWalletNotDeployed.selector));
        atomWarden.claimWithAuthorization(authorization, bundle);
    }

    function test_setters_successful() external {
        address newMultiVault = makeAddr("new-multivault");

        vm.prank(admin);
        atomWarden.setMultiVault(newMultiVault);
        vm.prank(admin);
        atomWarden.setClaimWindow(30 days);
        vm.prank(admin);
        atomWarden.setMinFeeThreshold(1 ether);

        assertEq(atomWarden.multiVault(), newMultiVault);
        assertEq(atomWarden.claimWindow(), 30 days);
        assertEq(atomWarden.minFeeThreshold(), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSABLE
    //////////////////////////////////////////////////////////////*/

    function test_initialize_isUnpaused() external view {
        assertFalse(atomWarden.paused());
    }

    function test_pause_revertsForNonAdmin() external {
        address nobody = makeAddr("non-admin");
        bytes32 adminRole = atomWarden.DEFAULT_ADMIN_ROLE();
        vm.prank(nobody);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, adminRole)
        );
        atomWarden.pause();
    }

    function test_unpause_revertsForNonAdmin() external {
        vm.prank(admin);
        atomWarden.pause();

        address nobody = makeAddr("non-admin");
        bytes32 adminRole = atomWarden.DEFAULT_ADMIN_ROLE();
        vm.prank(nobody);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, adminRole)
        );
        atomWarden.unpause();
    }

    function test_pause_blocksClaimOwnershipOverAddressAtom() external {
        bytes32 atomId = _setAddressAtom(claimant, false, false);

        vm.prank(admin);
        atomWarden.pause();

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    function test_pause_blocksClaimWithAuthorization() external {
        bytes32 atomId = _setAtom("paused-claim", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(admin);
        atomWarden.pause();

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_pause_blocksClaimAsCreatorAfterExpiry() external {
        vm.warp(DEFAULT_CLAIM_WINDOW + 1 days);
        bytes32 atomId = _setAtom("paused-creator", claimant, false, creator, uint48(block.timestamp - 8 days));
        multiVault.setAccumulatedFees(multiVault.atomWallets(atomId), DEFAULT_MIN_FEE_THRESHOLD);

        vm.prank(admin);
        atomWarden.pause();

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        atomWarden.claimAsCreatorAfterExpiry(atomId);
    }

    function test_pause_doesNotBlockGrantAtomWalletOwnership() external {
        // Operator path is intentionally NOT gated on pause — admins keep a manual
        // override during incidents. Lock that user-approved scope into a test.
        bytes32 atomId = _setAtom("paused-grant", claimant, false, address(0), 0);
        address newOwner = makeAddr("granted-while-paused");

        vm.prank(admin);
        atomWarden.pause();

        vm.prank(operator);
        atomWarden.grantAtomWalletOwnership(atomId, newOwner);

        assertEq(MockAtomWallet(multiVault.atomWallets(atomId)).owner(), newOwner);
    }

    function test_unpause_restoresClaimSurface() external {
        vm.prank(admin);
        atomWarden.pause();
        vm.prank(admin);
        atomWarden.unpause();

        bytes32 atomId = _setAddressAtom(claimant, false, false);
        vm.prank(claimant);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed());
    }

    /*//////////////////////////////////////////////////////////////
                          TIME-WINDOW CAPS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_setsMaxValidAfterAndMaxValidUntil() external view {
        assertEq(atomWarden.maxValidAfter(), DEFAULT_MAX_VALID_AFTER);
        assertEq(atomWarden.maxValidUntil(), DEFAULT_MAX_VALID_UNTIL);
    }

    function test_setMaxValidAfter_emitsEventAndRotates() external {
        uint48 newValue = uint48(45 minutes);

        vm.expectEmit(false, false, false, true, address(atomWarden));
        emit IAtomWarden.MaxValidAfterSet(DEFAULT_MAX_VALID_AFTER, newValue);

        vm.prank(admin);
        atomWarden.setMaxValidAfter(newValue);
        assertEq(atomWarden.maxValidAfter(), newValue);
    }

    function test_setMaxValidUntil_emitsEventAndRotates() external {
        uint48 newValue = uint48(14 days);

        vm.expectEmit(false, false, false, true, address(atomWarden));
        emit IAtomWarden.MaxValidUntilSet(DEFAULT_MAX_VALID_UNTIL, newValue);

        vm.prank(admin);
        atomWarden.setMaxValidUntil(newValue);
        assertEq(atomWarden.maxValidUntil(), newValue);
    }

    function test_setMaxValidAfter_revertsForNonAdmin() external {
        address nobody = makeAddr("not-admin");
        bytes32 adminRole = atomWarden.DEFAULT_ADMIN_ROLE();
        vm.prank(nobody);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, adminRole)
        );
        atomWarden.setMaxValidAfter(uint48(1 hours));
    }

    function test_setMaxValidUntil_revertsForNonAdmin() external {
        address nobody = makeAddr("not-admin");
        bytes32 adminRole = atomWarden.DEFAULT_ADMIN_ROLE();
        vm.prank(nobody);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, adminRole)
        );
        atomWarden.setMaxValidUntil(uint48(1 days));
    }

    function test_claimWithAuthorization_revertsWhenValidAfterTooFar() external {
        // Warp forward so we have headroom to schedule a future validAfter that
        // overshoots the cap without running into uint48 wrap-around.
        vm.warp(1_000_000);
        bytes32 atomId = _setAtom("validafter-cap", claimant, false, address(0), 0);

        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        // 1 second past `block.timestamp + maxValidAfter` — first cap branch fires.
        authorization.validAfter = uint48(block.timestamp + DEFAULT_MAX_VALID_AFTER + 1);
        // Pull validUntil up too so the base ordering check stays valid; the cap
        // branch we want is the validAfter one.
        authorization.validUntil = uint48(authorization.validAfter + 1 minutes);

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ValidityWindowTooLong.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_revertsWhenValidUntilTooFar() external {
        vm.warp(1_000_000);
        bytes32 atomId = _setAtom("validuntil-cap", claimant, false, address(0), 0);

        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        // validAfter stays in-window; only validUntil overshoots the cap.
        authorization.validAfter = uint48(block.timestamp - 1);
        authorization.validUntil = uint48(block.timestamp + DEFAULT_MAX_VALID_UNTIL + 1);

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ValidityWindowTooLong.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_succeedsAtBoundary() external {
        vm.warp(1_000_000);
        bytes32 atomId = _setAtom("boundary-cap", claimant, false, address(0), 0);

        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        // Pull validAfter into the past so the base ordering check passes against `now`,
        // then anchor validUntil exactly at `now + maxValidUntil` so the cap branch
        // sees `validUntil == now + maxValidUntil` (allowed by the `>` check).
        authorization.validAfter = uint48(block.timestamp - 1);
        authorization.validUntil = uint48(block.timestamp + DEFAULT_MAX_VALID_UNTIL);

        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, signature);

        assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed());
    }

    function test_setMaxValidUntil_zeroDisablesAllSignedClaims() external {
        // Setting maxValidUntil = 0 makes any `validUntil > block.timestamp` a violation,
        // and the basic time-window check requires `validUntil >= block.timestamp`. The
        // only allowed value left is `validUntil == block.timestamp`, which collapses the
        // sig validity window to a single block — effectively a finer-grained freeze.
        vm.prank(admin);
        atomWarden.setMaxValidUntil(0);

        bytes32 atomId = _setAtom("frozen-claims", claimant, false, address(0), 0);
        IAtomWarden.ClaimAuthorization memory authorization = _defaultAuthorization(atomId, 0);
        bytes memory signature = _signAuthorization(authorization, signerPrivateKey);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ValidityWindowTooLong.selector));
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setAddressAtom(address account, bool claimed, bool checksumFormat) internal returns (bytes32) {
        string memory atomData = checksumFormat ? Strings.toChecksumHexString(account) : Strings.toHexString(account);
        return _setAtom(atomData, account, claimed, address(0), 0);
    }

    function _setAtom(
        string memory data,
        address walletOwner,
        bool claimed,
        address atomCreator,
        uint48 createdAt
    )
        internal
        returns (bytes32 atomId)
    {
        atomId = multiVault.calculateAtomId(bytes(data));
        MockAtomWallet wallet = new MockAtomWallet(walletOwner);
        if (claimed) {
            wallet.completeClaim(walletOwner);
        }

        multiVault.setAtom(atomId, bytes(data), address(wallet), atomCreator, createdAt);
    }

    function _signAuthorization(
        IAtomWarden.ClaimAuthorization memory authorization,
        uint256 privateKey
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_AUTHORIZATION_TYPEHASH,
                authorization.claimant,
                authorization.atomId,
                authorization.claimType,
                authorization.nonce,
                authorization.validAfter,
                authorization.validUntil
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("AtomWarden")),
                keccak256(bytes("2")),
                block.chainid,
                address(atomWarden)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                          QUORUM TEST HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a fresh AtomWarden proxy initialized at v1 only (no `reinitialize()`
    ///      call), so quorum-bootstrap tests can observe the v2 reinit transition.
    function _freshUnreinitializedWarden() internal returns (AtomWarden) {
        MockMultiVault freshMultiVault = new MockMultiVault();
        freshMultiVault.setConfigAdmin(admin);

        AtomWarden freshImpl = new AtomWarden();
        TransparentUpgradeableProxy freshProxy =
            new TransparentUpgradeableProxy(address(freshImpl), makeAddr("layout-proxy-admin"), "");
        AtomWarden freshWarden = AtomWarden(address(freshProxy));

        freshWarden.initialize(
            admin,
            address(freshMultiVault),
            DEFAULT_CLAIM_WINDOW,
            DEFAULT_MIN_FEE_THRESHOLD,
            DEFAULT_SIGNATURE_THRESHOLD,
            DEFAULT_MAX_VALID_AFTER,
            DEFAULT_MAX_VALID_UNTIL
        );
        return freshWarden;
    }

    function _defaultAuthorization(
        bytes32 atomId,
        uint256 nonce
    )
        internal
        view
        returns (IAtomWarden.ClaimAuthorization memory)
    {
        return IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: nonce,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });
    }

    function _grantSignerKeys(uint256[] memory keys) internal {
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.startPrank(admin);
        for (uint256 i = 0; i < keys.length; ++i) {
            atomWarden.grantRole(signerRole, vm.addr(keys[i]));
        }
        vm.stopPrank();
    }

    function _setSignatureThreshold(uint256 threshold) internal {
        vm.prank(admin);
        atomWarden.setSignatureThreshold(threshold);
    }

    /// @dev Sorts the keys by their `vm.addr` ascending and concatenates ECDSA
    ///      signatures over the same EIP-712 digest in that order — the canonical
    ///      Gnosis-Safe-style bundle layout the contract expects.
    function _buildSortedSignatures(
        IAtomWarden.ClaimAuthorization memory authorization,
        uint256[] memory keys
    )
        internal
        view
        returns (bytes memory bundle)
    {
        bundle = _signInOrder(authorization, _sortKeysByAddress(keys));
    }

    /// @dev Sorts ascending and then reverses, so the resulting order is strictly
    ///      DESCENDING by recovered address — the canonical "violates ordering" case.
    function _buildReversedSignatures(
        IAtomWarden.ClaimAuthorization memory authorization,
        uint256[] memory keys
    )
        internal
        view
        returns (bytes memory bundle)
    {
        uint256[] memory sorted = _sortKeysByAddress(keys);
        uint256 n = sorted.length;
        uint256[] memory reversed = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            reversed[i] = sorted[n - 1 - i];
        }
        bundle = _signInOrder(authorization, reversed);
    }

    function _signInOrder(
        IAtomWarden.ClaimAuthorization memory authorization,
        uint256[] memory keys
    )
        internal
        view
        returns (bytes memory bundle)
    {
        for (uint256 i = 0; i < keys.length; ++i) {
            bundle = bytes.concat(bundle, _signAuthorization(authorization, keys[i]));
        }
    }

    function _sortKeysByAddress(uint256[] memory keys) internal pure returns (uint256[] memory) {
        uint256 n = keys.length;
        uint256[] memory sorted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            sorted[i] = keys[i];
        }
        // Insertion sort by recovered address; tiny N, gas/perf irrelevant.
        for (uint256 i = 1; i < n; ++i) {
            uint256 currentKey = sorted[i];
            address currentAddr = vm.addr(currentKey);
            uint256 j = i;
            while (j > 0 && vm.addr(sorted[j - 1]) > currentAddr) {
                sorted[j] = sorted[j - 1];
                --j;
            }
            sorted[j] = currentKey;
        }
        return sorted;
    }

    function _isAscendingByAddress(uint256[] memory keys) internal pure returns (bool) {
        for (uint256 i = 1; i < keys.length; ++i) {
            if (vm.addr(keys[i]) <= vm.addr(keys[i - 1])) {
                return false;
            }
        }
        return true;
    }

    /// @dev Fisher-Yates shuffle seeded by `seed`. Distinct seeds may produce the same
    ///      permutation as the canonical order — that case is handled in the fuzz test.
    function _permuteKeys(uint256[] memory keys, uint256 seed) internal pure returns (uint256[] memory) {
        uint256 n = keys.length;
        uint256[] memory permuted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            permuted[i] = keys[i];
        }
        for (uint256 i = n - 1; i > 0; --i) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint256 j = seed % (i + 1);
            (permuted[i], permuted[j]) = (permuted[j], permuted[i]);
        }
        return permuted;
    }

    /// @dev Returns `n` distinct private keys derived from `seed`. Distinctness is
    ///      enforced by retrying on collision — secp256k1 makes collisions astronomically
    ///      unlikely so the loop terminates immediately in practice.
    function _deriveDistinctKeys(uint256 seed, uint256 n) internal pure returns (uint256[] memory) {
        uint256[] memory keys = new uint256[](n);
        uint256 produced;
        uint256 nonce;
        while (produced < n) {
            uint256 candidate = uint256(keccak256(abi.encode(seed, nonce)));
            ++nonce;
            // secp256k1 private keys must be in [1, n-1]; clamp away from extremes.
            candidate = bound(candidate, 1, type(uint128).max);
            bool unique = true;
            for (uint256 i = 0; i < produced; ++i) {
                if (keys[i] == candidate) {
                    unique = false;
                    break;
                }
            }
            if (unique) {
                keys[produced] = candidate;
                ++produced;
            }
        }
        return keys;
    }

    /// @dev Independent ECDSA recovery for the EIP-712 frozen vector test.
    function _recoverFromBundle(bytes32 digest, bytes memory bundle) internal pure returns (address) {
        require(bundle.length == 65, "expected single signature");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(bundle, 0x20))
            s := mload(add(bundle, 0x40))
            v := byte(0, mload(add(bundle, 0x60)))
        }
        return ecrecover(digest, v, r, s);
    }
}
