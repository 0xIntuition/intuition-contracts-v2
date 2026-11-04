// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { MockMultiVault, MockAtomWallet } from "tests/unit/AtomWarden/AtomWarden.t.sol";

/// @title  AtomWardenQuorumSoundness
/// @notice AtomWarden quorum soundness, pushing past the existing
///         high-s / stale-nonce / revoke-below-threshold suite.
///
/// Invariant under test: a successful `claimWithAuthorization` requires at least `signatureThreshold`
/// DISTINCT, currently-authorized signer keys over the live EIP-712 digest, with no replay across
/// chains and no padding with duplicate or contract "signers".
///
/// Net-new cases: (a) threshold RAISED between sign and execute; (b) duplicate-signer padding
/// defeated by the strictly-ascending-order rule; (c) ERC-1271 contract signers cannot participate
/// because verification is raw ECDSA recovery; (d) a chain-id change invalidates a prior signature.
///
/// Verdict: DEFENDED. All cases revert. Recorded with defending mechanism (segment-count vs
/// threshold check, ascending-order dedup, `ECDSA.tryRecover` + `SIGNER_ROLE` check, EIP-712 domain
/// binding live `block.chainid`).
contract AtomWardenQuorumSoundnessTest is Test {
    bytes32 internal constant CLAIM_AUTHORIZATION_TYPEHASH = keccak256(
        "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
    );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    AtomWarden internal atomWarden;
    MockMultiVault internal multiVault;

    address internal admin;
    address internal claimant;

    uint256 internal constant CLAIM_WINDOW = 7 days;
    uint256 internal constant MIN_FEE = 0.25 ether;
    uint48 internal constant MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant MAX_VALID_UNTIL = uint48(7 days);
    uint256 internal constant MAX_CLAIMS_PER_WINDOW = 100;
    uint256 internal constant CLAIM_CAP_WINDOW = 1 days;

    function setUp() external {
        admin = makeAddr("admin");
        claimant = makeAddr("claimant");

        multiVault = new MockMultiVault();
        multiVault.setConfigAdmin(admin);

        AtomWarden impl = new AtomWarden();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, "");
        atomWarden = AtomWarden(address(proxy));
        atomWarden.initialize(
            admin,
            address(multiVault),
            CLAIM_WINDOW,
            MIN_FEE,
            1,
            MAX_VALID_AFTER,
            MAX_VALID_UNTIL,
            MAX_CLAIMS_PER_WINDOW,
            CLAIM_CAP_WINDOW
        );
    }

    /// @dev Raising the threshold after a single-signer signature is produced makes the previously
    ///      sufficient bundle fall short: `segments (1) < threshold (2)` reverts before any recovery.
    function test_thresholdRaisedAfterSign_insufficientSignersReverts() external {
        uint256 keyA = 0xA11CE;
        uint256 keyB = 0xB0B;
        _grantSigner(vm.addr(keyA));
        _grantSigner(vm.addr(keyB));

        bytes32 atomId = _setAtom("t4-threshold-raise");
        IAtomWarden.ClaimAuthorization memory auth = _defaultAuth(atomId, 0);
        bytes memory singleSig = _sign(auth, keyA); // valid under threshold == 1

        // Admin raises the quorum to 2 after the (single) signature was produced.
        vm.prank(admin);
        atomWarden.setSignatureThreshold(2);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InsufficientSigners.selector));
        atomWarden.claimWithAuthorization(auth, singleSig);
    }

    /// @dev A single signer cannot satisfy a 2-of-N quorum by submitting the same signature twice:
    ///      both segments recover to the same address, so the second fails the strictly-ascending
    ///      order rule.
    function test_duplicateSignerPadding_nonCanonicalOrderReverts() external {
        uint256 keyA = 0xA11CE;
        _grantSigner(vm.addr(keyA));
        _grantSigner(vm.addr(0xB0B)); // a second role-holder exists so threshold 2 is configurable
        vm.prank(admin);
        atomWarden.setSignatureThreshold(2);

        bytes32 atomId = _setAtom("t4-dup");
        IAtomWarden.ClaimAuthorization memory auth = _defaultAuth(atomId, 0);
        bytes memory oneSig = _sign(auth, keyA);
        bytes memory duplicated = bytes.concat(oneSig, oneSig);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_NonCanonicalSignerOrder.selector));
        atomWarden.claimWithAuthorization(auth, duplicated);
    }

    /// @dev When only a contract address holds SIGNER_ROLE, the quorum is unsatisfiable: every
    ///      65-byte segment recovers to an EOA (no private key maps to a contract address), and that
    ///      EOA does not hold the role. ERC-1271 contract signers cannot participate.
    function test_contractSignerCannotSatisfyQuorum() external {
        // Grant the role only to a contract (use the MultiVault mock's address as a stand-in).
        _grantSigner(address(multiVault));

        bytes32 atomId = _setAtom("t4-contract-signer");
        IAtomWarden.ClaimAuthorization memory auth = _defaultAuth(atomId, 0);
        // Any real ECDSA signature recovers to an EOA, which is not the role-holding contract.
        bytes memory eoaSig = _sign(auth, 0xC0FFEE);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(auth, eoaSig);
    }

    /// @dev A signature produced under one chain id does not verify after a chain-id change: the
    ///      EIP-712 domain separator binds the live `block.chainid`, so the digest differs and the
    ///      recovered address no longer holds the role.
    function test_chainIdChangeInvalidatesSignature() external {
        uint256 keyA = 0xA11CE;
        _grantSigner(vm.addr(keyA));

        bytes32 atomId = _setAtom("t4-chainid");
        IAtomWarden.ClaimAuthorization memory auth = _defaultAuth(atomId, 0);

        // Sign under the original chain id.
        bytes memory sig = _sign(auth, keyA);

        // Fork to a different chain id; the cached domain separator is rebuilt on read.
        vm.chainId(block.chainid + 1);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(auth, sig);
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    function _grantSigner(address account) internal {
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.prank(admin);
        atomWarden.grantRole(signerRole, account);
    }

    function _setAtom(string memory data) internal returns (bytes32 atomId) {
        atomId = multiVault.calculateAtomId(bytes(data));
        MockAtomWallet wallet = new MockAtomWallet(address(atomWarden));
        multiVault.setAtom(atomId, bytes(data), address(wallet), address(0), 0);
    }

    function _defaultAuth(bytes32 atomId, uint256 nonce) internal view returns (IAtomWarden.ClaimAuthorization memory) {
        return IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: nonce,
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });
    }

    function _digest(IAtomWarden.ClaimAuthorization memory auth) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("AtomWarden")),
                keccak256(bytes("2")),
                block.chainid,
                address(atomWarden)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_AUTHORIZATION_TYPEHASH,
                auth.claimant,
                auth.atomId,
                auth.claimType,
                auth.nonce,
                auth.validAfter,
                auth.validUntil
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _sign(IAtomWarden.ClaimAuthorization memory auth, uint256 key) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, _digest(auth));
        return abi.encodePacked(r, s, v);
    }
}
