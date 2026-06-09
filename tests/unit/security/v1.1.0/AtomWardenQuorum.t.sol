// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { MockMultiVault, MockAtomWallet } from "tests/unit/AtomWarden/AtomWarden.t.sol";

/// @title  Track 4 — AtomWarden quorum replay / malleability hunt (ENG-12460)
/// @notice Targets the gaps not already nailed by tests/unit/AtomWarden/AtomWarden.t.sol:
///         (1) real ECDSA signature malleability via the high-s complement, and
///         (2) signer revocation dropping the live set below threshold. Both are
///         NEGATIVE results — the defense holds and the claim reverts.
contract AtomWardenQuorumTest is Test {
    bytes32 internal constant CLAIM_AUTHORIZATION_TYPEHASH = keccak256(
        "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
    );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /// @dev secp256k1 group order N; malleated signatures use s' = N - s.
    uint256 internal constant SECP256K1_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    AtomWarden internal atomWarden;
    MockMultiVault internal multiVault;

    address internal admin;
    address internal claimant;
    uint256 internal signerKey = 0xBEEF;
    address internal signer;

    uint256 internal constant CLAIM_WINDOW = 7 days;
    uint256 internal constant MIN_FEE = 0.25 ether;
    uint48 internal constant MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant MAX_VALID_UNTIL = uint48(7 days);

    function setUp() external {
        admin = makeAddr("admin");
        claimant = makeAddr("claimant");
        signer = vm.addr(signerKey);

        multiVault = new MockMultiVault();
        multiVault.setConfigAdmin(admin);

        AtomWarden impl = new AtomWarden();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, "");
        atomWarden = AtomWarden(address(proxy));
        atomWarden.initialize(admin, address(multiVault), CLAIM_WINDOW, MIN_FEE, 1, MAX_VALID_AFTER, MAX_VALID_UNTIL);

        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.prank(admin);
        atomWarden.grantRole(signerRole, signer);
    }

    /// @dev H1: signature malleability. Given a valid (r,s,v), the complement
    ///      (r, N-s, v^1) recovers the same address under naive ecrecover, but OZ
    ///      ECDSA.tryRecover rejects high-s ⇒ the warden surfaces InvalidSignature.
    ///      A malleated bundle cannot satisfy the quorum.
    function test_highSMalleability_reverts() external {
        bytes32 atomId = _setAtom("t4-malleable");
        IAtomWarden.ClaimAuthorization memory auth = _defaultAuth(atomId, 0);
        bytes32 digest = _digest(auth);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);

        // Sanity: the canonical (low-s) signature is accepted.
        uint256 snap = vm.snapshotState();
        vm.prank(claimant);
        atomWarden.claimWithAuthorization(auth, abi.encodePacked(r, s, v));
        assertTrue(MockAtomWallet(multiVault.atomWallets(atomId)).isClaimed(), "canonical sig accepted");
        require(vm.revertToState(snap), "revert failed");

        // Malleate to the high-s complement and flip v.
        bytes32 sHigh = bytes32(SECP256K1_N - uint256(s));
        uint8 vFlipped = v == 27 ? 28 : 27;
        bytes memory malleated = abi.encodePacked(r, sHigh, vFlipped);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(auth, malleated);
    }

    /// @dev H2: a genuine cross-atom claim needs its OWN fresh-nonce signature; the
    ///      first atom's signature cannot be replayed onto a second atom (stale
    ///      nonce), while a correctly re-signed fresh-nonce claim succeeds.
    function test_crossAtomReplay_staleNonceReverts_freshNonceWorks() external {
        bytes32 atom1 = _setAtom("t4-atom1");
        IAtomWarden.ClaimAuthorization memory auth1 = _defaultAuth(atom1, 0);
        bytes memory sig1 = _sign(auth1, signerKey);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(auth1, sig1);
        assertEq(atomWarden.claimNonces(claimant), 1, "nonce advanced");

        // Replay atom1's signature against a new atom with the now-stale nonce 0.
        bytes32 atom2 = _setAtom("t4-atom2");
        IAtomWarden.ClaimAuthorization memory staleAuth = _defaultAuth(atom2, 0);
        bytes memory staleSig = _sign(staleAuth, signerKey);
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidNonce.selector));
        atomWarden.claimWithAuthorization(staleAuth, staleSig);

        // A correctly re-signed fresh-nonce claim on atom2 succeeds.
        IAtomWarden.ClaimAuthorization memory freshAuth = _defaultAuth(atom2, 1);
        bytes memory freshSig = _sign(freshAuth, signerKey);
        vm.prank(claimant);
        atomWarden.claimWithAuthorization(freshAuth, freshSig);
        assertTrue(MockAtomWallet(multiVault.atomWallets(atom2)).isClaimed(), "fresh-nonce claim ok");
    }

    /// @dev H3: revoking a signer drops the live SIGNER_ROLE set below threshold.
    ///      A previously-valid 2-of-2 bundle now fails loudly (the revoked signer no
    ///      longer holds the role) rather than silently degrading security.
    function test_signerRevokedBelowThreshold_failsLoud() external {
        uint256 keyA = 0xA11CE;
        uint256 keyB = 0xB0B;
        address sA = vm.addr(keyA);
        address sB = vm.addr(keyB);
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.startPrank(admin);
        atomWarden.grantRole(signerRole, sA);
        atomWarden.grantRole(signerRole, sB);
        atomWarden.setSignatureThreshold(2);
        vm.stopPrank();

        bytes32 atomId = _setAtom("t4-revoke");
        IAtomWarden.ClaimAuthorization memory auth = _defaultAuth(atomId, 0);
        bytes memory bundle = _sortedBundle(auth, keyA, keyB);

        // Revoke one signer; the bundle's two sigs now include a non-SIGNER address.
        vm.prank(admin);
        atomWarden.revokeRole(signerRole, sA);

        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidSignature.selector));
        atomWarden.claimWithAuthorization(auth, bundle);
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

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

    /// @dev Concatenate two single-signer sigs in strictly-ascending recovered-address order.
    function _sortedBundle(
        IAtomWarden.ClaimAuthorization memory auth,
        uint256 k1,
        uint256 k2
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory s1 = _sign(auth, k1);
        bytes memory s2 = _sign(auth, k2);
        return vm.addr(k1) < vm.addr(k2) ? bytes.concat(s1, s2) : bytes.concat(s2, s1);
    }
}
