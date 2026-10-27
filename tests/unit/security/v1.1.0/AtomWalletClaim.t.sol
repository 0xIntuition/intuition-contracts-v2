// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract AtomWalletClaimTest is BaseTest {
    bytes32 internal constant CLAIM_AUTHORIZATION_TYPEHASH = keccak256(
        "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
    );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    uint256 internal constant WALLET_CONFIG_ATOM_WARDEN_SLOT = 14;
    uint256 internal constant SIGNER_PRIVATE_KEY = 0xA11CE;
    uint256 internal constant CLAIM_WINDOW = 7 days;
    uint48 internal constant MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant MAX_VALID_UNTIL = uint48(7 days);
    uint256 internal constant MAX_CLAIMS_PER_WINDOW = 100;
    uint256 internal constant CLAIM_CAP_WINDOW = 1 days;

    AtomWarden internal atomWarden;
    address internal signer;

    function setUp() public override {
        super.setUp();
        vm.stopPrank();

        signer = vm.addr(SIGNER_PRIVATE_KEY);
        AtomWarden atomWardenImpl = new AtomWarden();
        TransparentUpgradeableProxy atomWardenProxy =
            new TransparentUpgradeableProxy(address(atomWardenImpl), users.admin, "");
        atomWarden = AtomWarden(address(atomWardenProxy));
        atomWarden.initialize(
            users.admin,
            address(protocol.multiVault),
            CLAIM_WINDOW,
            0,
            1,
            MAX_VALID_AFTER,
            MAX_VALID_UNTIL,
            MAX_CLAIMS_PER_WINDOW,
            CLAIM_CAP_WINDOW
        );

        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.prank(users.admin);
        atomWarden.grantRole(signerRole, signer);

        vm.store(
            address(protocol.multiVault),
            bytes32(WALLET_CONFIG_ATOM_WARDEN_SLOT),
            bytes32(uint256(uint160(address(atomWarden))))
        );
    }

    function test_claimWithAuthorization_revertsBeforeWalletDeployment() external {
        bytes32 atomId = _createAtom("claim-before-deploy", users.alice);
        IAtomWarden.ClaimAuthorization memory authorization = _authorization(users.alice, atomId);
        bytes memory signature = _signAuthorization(authorization);

        vm.prank(users.alice);
        vm.expectRevert(IAtomWarden.AtomWarden_AtomWalletNotDeployed.selector);
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_claimWithAuthorization_revertsForNonClaimantSubmitter() external {
        bytes32 atomId = _createAtomAndDeployWallet("non-claimant", users.alice);
        IAtomWarden.ClaimAuthorization memory authorization = _authorization(users.alice, atomId);
        bytes memory signature = _signAuthorization(authorization);

        vm.prank(users.bob);
        vm.expectRevert(IAtomWarden.AtomWarden_UnauthorizedClaimant.selector);
        atomWarden.claimWithAuthorization(authorization, signature);
    }

    function test_factoryDeploy_returnsPredictedWalletAndAlreadyDeployedAddress() external {
        bytes32 atomId = _createAtom("deterministic-wallet", users.alice);
        address predictedBefore = protocol.multiVault.computeAtomWalletAddr(atomId);
        assertEq(predictedBefore.code.length, 0, "wallet starts undeployed");

        vm.prank(users.bob);
        address deployed = protocol.atomWalletFactory.deployAtomWallet(atomId);
        assertEq(deployed, predictedBefore, "factory deploys predicted CREATE2 address");

        address predictedAfter = protocol.multiVault.computeAtomWalletAddr(atomId);
        assertEq(predictedAfter, predictedBefore, "computed address stable after deploy");

        vm.prank(users.charlie);
        address deployedAgain = protocol.atomWalletFactory.deployAtomWallet(atomId);
        assertEq(deployedAgain, deployed, "factory returns already deployed wallet");

        AtomWallet wallet = AtomWallet(payable(deployed));
        assertEq(wallet.termId(), atomId, "wallet termId bound at initialization");
        assertEq(
            address(wallet.multiVault()), address(protocol.multiVault), "wallet MultiVault bound at initialization"
        );
        assertEq(wallet.owner(), address(atomWarden), "pre-claim owner resolves to Warden");
        assertFalse(wallet.isClaimed(), "wallet remains unclaimed after factory deployment");
    }

    function test_claimWithAuthorization_claimsExactComputedWalletOnce() external {
        bytes32 atomId = _createAtomAndDeployWallet("claim-once", users.alice);
        address walletAddress = protocol.multiVault.computeAtomWalletAddr(atomId);

        IAtomWarden.ClaimAuthorization memory authorization = _authorization(users.alice, atomId);
        bytes memory signature = _signAuthorization(authorization);

        vm.prank(users.alice);
        atomWarden.claimWithAuthorization(authorization, signature);

        AtomWallet wallet = AtomWallet(payable(walletAddress));
        assertTrue(wallet.isClaimed(), "wallet marked claimed");
        assertEq(wallet.owner(), users.alice, "claimant owns exact computed wallet");
        assertEq(atomWarden.claimNonces(users.alice), authorization.nonce + 1, "nonce increments");

        IAtomWarden.ClaimAuthorization memory bobAuthorization = _authorization(users.bob, atomId);
        bytes memory bobSignature = _signAuthorization(bobAuthorization);

        vm.prank(users.bob);
        vm.expectRevert(IAtomWarden.AtomWarden_AlreadyClaimed.selector);
        atomWarden.claimWithAuthorization(bobAuthorization, bobSignature);
    }

    function test_claimAsCreatorAfterExpiry_allowsExactBoundaryOnly() external {
        bytes32 atomId = _createAtomAndDeployWallet("creator-boundary", users.alice);
        uint48 createdAt = protocol.multiVault.getAtomCreatedAt(atomId);

        vm.warp(uint256(createdAt) + CLAIM_WINDOW - 1);
        vm.prank(users.alice);
        vm.expectRevert(IAtomWarden.AtomWarden_ClaimWindowNotElapsed.selector);
        atomWarden.claimAsCreatorAfterExpiry(atomId);

        vm.warp(uint256(createdAt) + CLAIM_WINDOW);
        vm.prank(users.alice);
        atomWarden.claimAsCreatorAfterExpiry(atomId);

        AtomWallet wallet = AtomWallet(payable(protocol.multiVault.computeAtomWalletAddr(atomId)));
        assertTrue(wallet.isClaimed(), "creator claim succeeds at exact expiry");
        assertEq(wallet.owner(), users.alice, "creator owns wallet");
    }

    function _createAtomAndDeployWallet(string memory label, address creator) internal returns (bytes32 atomId) {
        atomId = _createAtom(label, creator);
        address predicted = protocol.multiVault.computeAtomWalletAddr(atomId);
        address deployed = protocol.atomWalletFactory.deployAtomWallet(atomId);
        assertEq(deployed, predicted, "factory deploys computed wallet");
    }

    function _createAtom(string memory label, address creator) internal returns (bytes32 atomId) {
        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked(label);
        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;

        vm.startPrank(creator);
        bytes32[] memory ids = protocol.multiVault.createAtoms{ value: atomCost }(atomData, assets);
        vm.stopPrank();

        atomId = ids[0];
    }

    function _authorization(address claimant, bytes32 atomId)
        internal
        view
        returns (IAtomWarden.ClaimAuthorization memory authorization)
    {
        authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: atomWarden.claimNonces(claimant),
            validAfter: uint48(block.timestamp),
            validUntil: uint48(block.timestamp + 1 days)
        });
    }

    function _signAuthorization(IAtomWarden.ClaimAuthorization memory authorization)
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
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("AtomWarden")),
                keccak256(bytes("2")),
                block.chainid,
                address(atomWarden)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
