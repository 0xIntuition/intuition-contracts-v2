// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { WebAuthn } from "solady/utils/WebAuthn.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { P256 } from "solady/utils/P256.sol";

/// @title  AtomWalletAuthEdges
/// @notice Hypothesis 5 (deep pre-audit): AtomWallet ERC-4337 / P-256 auth and claim-transition
///         edges, including the **regression suite for F-002**.
///
/// F-002 (FIXED): `CoinbaseSmartWalletLib.isValidSignature` previously decoded the inline-encoded
/// `(ownerIndex, signatureData)` wrapper as `abi.decode(_, (SignatureWrapper))`, which reads the
/// first word as a struct offset. That word is `ownerIndex`, so decoding only worked at index 0 and
/// reverted for any owner at index >= 1 — locking out every co-owner, every P-256/passkey owner
/// (only addable at index >= 1), and the post-`transferOwnership` owner. The fix decodes the inline
/// `(uint256, bytes)` tuple, which works for every index. These tests assert the fixed behavior:
/// owners at any index can authenticate; removed owners cannot; out-of-range and malformed inputs
/// return the ERC-1271 failure magic non-revertingly (never revert), preserving the ERC-4337
/// non-revert contract. Defended negatives from the original takeover surface are retained.
contract AtomWalletAuthEdgesTest is BaseTest {
    bytes4 internal constant ERC1271_MAGIC = 0x1626ba7e;
    bytes4 internal constant ERC1271_FAIL = 0xffffffff;

    /// @dev Solady's P-256 verifier bytecode, etched at the RIP-7212 precompile address in
    ///      setUp so passkey (WebAuthn) validation runs locally. Production chains expose the
    ///      RIP-7212 precompile natively; this only makes the precompile available under Foundry.
    bytes private constant _P256_VERIFIER_BYTECODE =
        hex"3d604052610216565b60008060006ffffffffeffffffffffffffffffffffff60601b19808687098188890982838389096004098384858485093d510985868b8c096003090891508384828308850385848509089650838485858609600809850385868a880385088509089550505050808188880960020991505093509350939050565b81513d83015160408401516ffffffffeffffffffffffffffffffffff60601b19808384098183840982838388096004098384858485093d510985868a8b096003090896508384828308850385898a09089150610102848587890960020985868787880960080987038788878a0387088c0908848b523d8b015260408a0152565b505050505050505050565b81513d830151604084015185513d87015160408801518361013d578287523d870182905260408701819052610102565b80610157578587523d870185905260408701849052610102565b6ffffffffeffffffffffffffffffffffff60601b19808586098183840982818a099850828385830989099750508188830383838809089450818783038384898509870908935050826101be57836101be576101b28a89610082565b50505050505050505050565b808485098181860982828a09985082838a8b0884038483860386898a09080891506102088384868a0988098485848c09860386878789038f088a0908848d523d8d015260408c0152565b505050505050505050505050565b6020357fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325513d6040357f7fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a88111156102695782035b60206108005260206108205260206108405280610860526002830361088052826108a0526ffffffffeffffffffffffffffffffffff60601b198060031860205260603560803560203d60c061080060055afa60203d1416837f5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b8585873d5189898a09080908848384091484831085851016888710871510898b108b151016609f3611161616166103195760206080f35b60809182523d820152600160c08190527f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2966102009081527f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f53d909101526102405261038992509050610100610082565b610397610200610400610082565b6103a7610100608061018061010d565b6103b7610200608061028061010d565b6103c861020061010061030061010d565b6103d961020061018061038061010d565b6103e9610400608061048061010d565b6103fa61040061010061050061010d565b61040b61040061018061058061010d565b61041c61040061020061060061010d565b61042c610600608061068061010d565b61043d61060061010061070061010d565b61044e61060061018061078061010d565b81815182350982825185098283846ffffffffeffffffffffffffffffffffff60601b193d515b82156105245781858609828485098384838809600409848586848509860986878a8b096003090885868384088703878384090886878887880960080988038889848b03870885090887888a8d096002098882830996508881820995508889888509600409945088898a8889098a098a8b86870960030908935088898687088a038a868709089a5088898284096002099950505050858687868709600809870387888b8a0386088409089850505050505b61018086891b60f71c16610600888a1b60f51c16176040810151801585151715610564578061055357506105fe565b81513d8301519750955093506105fe565b83858609848283098581890986878584098b0991508681880388858851090887838903898a8c88093d8a015109089350836105b957806105b9576105a9898c8c610008565b9a509b50995050505050506105fe565b8781820988818309898285099350898a8586088b038b838d038d8a8b0908089b50898a8287098b038b8c8f8e0388088909089c5050508788868b098209985050505050505b5082156106af5781858609828485098384838809600409848586848509860986878a8b096003090885868384088703878384090886878887880960080988038889848b03870885090887888a8d096002098882830996508881820995508889888509600409945088898a8889098a098a8b86870960030908935088898687088a038a868709089a5088898284096002099950505050858687868709600809870387888b8a0386088409089850505050505b61018086891b60f51c16610600888a1b60f31c161760408101518015851517156106ef57806106de5750610789565b81513d830151975095509350610789565b83858609848283098581890986878584098b0991508681880388858851090887838903898a8c88093d8a01510908935083610744578061074457610734898c8c610008565b9a509b5099505050505050610789565b8781820988818309898285099350898a8586088b038b838d038d8a8b0908089b50898a8287098b038b8c8f8e0388088909089c5050508788868b098209985050505050505b50600488019760fb19016104745750816107a2573d6040f35b81610860526002810361088052806108a0523d3d60c061080060055afa898983843d513d510987090614163d525050505050505050503d3df3fea264697066735822122063ce32ec0e56e7893a1f6101795ce2e38aca14dd12adb703c71fe3bee27da71e64736f6c634300081a0033";

    AtomWallet internal wallet;
    address internal warden;
    address internal attacker;
    uint256 internal attackerKey = 0xA77ACC;

    function setUp() public override {
        super.setUp();
        vm.etch(P256.RIP_PRECOMPILE, _P256_VERIFIER_BYTECODE);
        warden = protocol.multiVault.getAtomWarden();
        attacker = vm.addr(attackerKey);

        bytes32 atomId = createSimpleAtom("h5-wallet", ATOM_COST[0], users.alice);
        wallet = AtomWallet(payable(protocol.atomWalletFactory.deployAtomWallet(atomId)));
    }

    /* =================================================== */
    /*            F-002 REGRESSION — POSITIVE PATHS        */
    /* =================================================== */

    /// @dev Control: the index-0 primary owner validates (worked before and after the fix).
    function test_index0PrimaryOwnerValidates() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("h5-owner0");
        resetPrank(warden);
        wallet.completeClaim(owner);

        bytes32 hash = keccak256("index0");
        assertEq(
            wallet.isValidSignature(hash, _wrapEoaSig(0, hash, ownerKey)), ERC1271_MAGIC, "index-0 owner validates"
        );
    }

    /// @dev F-002 core: multiple co-owners each authenticate at their own (non-zero) index.
    function test_multipleCoOwnersEachValidateAtTheirIndex() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("h5-owner");
        (address co1, uint256 co1Key) = makeAddrAndKey("h5-co1");
        (address co2, uint256 co2Key) = makeAddrAndKey("h5-co2");

        resetPrank(warden);
        wallet.completeClaim(owner);
        resetPrank(owner);
        wallet.addOwnerAddress(co1); // index 1
        wallet.addOwnerAddress(co2); // index 2

        assertEq(wallet.nextOwnerIndex(), 3, "three owners registered at indices 0,1,2");

        bytes32 hash = keccak256("multi-owner");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(0, hash, ownerKey)), ERC1271_MAGIC, "owner@0 validates");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(1, hash, co1Key)), ERC1271_MAGIC, "co-owner@1 validates");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(2, hash, co2Key)), ERC1271_MAGIC, "co-owner@2 validates");

        // A signature from a non-owner at any index fails (returned magic, not a revert).
        assertEq(
            wallet.isValidSignature(hash, _wrapEoaSig(1, hash, attackerKey)), ERC1271_FAIL, "non-owner sig@1 fails"
        );
    }

    /// @dev F-002: removing an owner revokes only that owner; the others keep validating, and the
    ///      removed owner's signature returns the failure magic (non-reverting).
    function test_removeOwner_revokesOnlyThatOwner() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("h5-rm-owner");
        (address co1, uint256 co1Key) = makeAddrAndKey("h5-rm-co1");
        (address co2, uint256 co2Key) = makeAddrAndKey("h5-rm-co2");

        resetPrank(warden);
        wallet.completeClaim(owner);
        resetPrank(owner);
        wallet.addOwnerAddress(co1); // index 1
        wallet.addOwnerAddress(co2); // index 2

        // Remove co1 at index 1.
        wallet.removeOwnerAtIndex(1, abi.encode(co1));

        bytes32 hash = keccak256("after-remove");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(1, hash, co1Key)), ERC1271_FAIL, "removed co-owner@1 fails");
        assertEq(
            wallet.isValidSignature(hash, _wrapEoaSig(0, hash, ownerKey)), ERC1271_MAGIC, "owner@0 still validates"
        );
        assertEq(
            wallet.isValidSignature(hash, _wrapEoaSig(2, hash, co2Key)), ERC1271_MAGIC, "co-owner@2 still validates"
        );
    }

    /// @dev F-002: re-adding a previously-removed owner lands it at a fresh (monotonic) index and it
    ///      validates there; the vacated index returns failure.
    function test_reAddOwner_landsAtNewIndexAndValidates() public {
        (address owner,) = makeAddrAndKey("h5-readd-owner");
        (address co1, uint256 co1Key) = makeAddrAndKey("h5-readd-co1");

        resetPrank(warden);
        wallet.completeClaim(owner);
        resetPrank(owner);
        wallet.addOwnerAddress(co1); // index 1
        wallet.removeOwnerAtIndex(1, abi.encode(co1)); // vacate index 1
        wallet.addOwnerAddress(co1); // re-add -> index 2 (monotonic)

        assertEq(wallet.nextOwnerIndex(), 3, "re-add advances the index counter");

        bytes32 hash = keccak256("re-add");
        assertEq(
            wallet.isValidSignature(hash, _wrapEoaSig(2, hash, co1Key)), ERC1271_MAGIC, "re-added owner@2 validates"
        );
        // Index 1 is vacated -> empty owner bytes -> failure magic (non-reverting).
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(1, hash, co1Key)), ERC1271_FAIL, "vacated index@1 fails");
    }

    /// @dev F-002: after `transferOwnership`, the new primary owner (now at index 1) authenticates,
    ///      and the rotated-out owner at the vacated index 0 does not.
    function test_postTransferOwnership_newOwnerValidates() public {
        (address oldOwner, uint256 oldKey) = makeAddrAndKey("h5-old");
        (address newOwner, uint256 newKey) = makeAddrAndKey("h5-new");

        resetPrank(warden);
        wallet.completeClaim(oldOwner);
        resetPrank(oldOwner);
        wallet.transferOwnership(newOwner);

        assertEq(wallet.owner(), newOwner, "owner() reports the new primary owner");

        bytes32 hash = keccak256("post-transfer");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(1, hash, newKey)), ERC1271_MAGIC, "new owner@1 validates");
        assertEq(
            wallet.isValidSignature(hash, _wrapEoaSig(0, hash, oldKey)), ERC1271_FAIL, "old owner@0 vacated -> fails"
        );
    }

    /// @dev F-002: combined EOA + passkey model. The EOA owner at index 0 validates; the P-256
    ///      passkey owner at index 1 is now REACHED by the validator (the inline decode no longer
    ///      reverts at index >= 1), returning the failure magic non-revertingly for a malformed
    ///      WebAuthn payload. A positively-validated P-256 vector is covered by
    ///      `test_F002_passkeyCoOwnerValidatesWithRealWebAuthnSignature`.
    function test_eoaPlusPasskey_eoaValidates_passkeyReachable() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("h5-combo-eoa");
        resetPrank(warden);
        wallet.completeClaim(owner);
        resetPrank(owner);
        wallet.addOwnerPublicKey(bytes32(uint256(0x1111)), bytes32(uint256(0x2222))); // passkey at index 1

        bytes32 hash = keccak256("combo");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(0, hash, ownerKey)), ERC1271_MAGIC, "EOA owner@0 validates");

        // Passkey owner@1 is reachable: non-reverting, returns failure for a malformed WebAuthn blob.
        (bool reverted, bytes4 ret) = _callIsValidSignature(hash, abi.encode(uint256(1), bytes(hex"deadbeefdeadbeef")));
        assertFalse(reverted, "passkey index decode no longer reverts (F-002 fixed)");
        assertEq(ret, ERC1271_FAIL, "malformed passkey payload returns failure magic");
    }

    /// @dev A P-256 passkey co-owner at index 1 is reachable by the validator, and the protocol does
    ///      NOT allow a pure passkey-only wallet: the primary (index-0 address) owner cannot be
    ///      removed, so every wallet retains an address owner. This bounds F-002's worst case — there
    ///      is always an address principal that can act via direct calls even if signature validation
    ///      for a passkey were ever to regress.
    function test_passkeyCoOwnerReachable_primaryOwnerCannotBeRemoved() public {
        (address owner,) = makeAddrAndKey("h5-passkey-co");
        resetPrank(warden);
        wallet.completeClaim(owner);
        resetPrank(owner);
        wallet.addOwnerPublicKey(bytes32(uint256(0xAAAA)), bytes32(uint256(0xBBBB))); // passkey at index 1

        assertEq(wallet.ownerAtIndex(1).length, 64, "passkey occupies index 1 (64-byte key)");

        bytes32 hash = keccak256("passkey-co");
        // The passkey index is reachable (non-reverting); malformed payloads fail cleanly.
        (bool reverted, bytes4 ret) = _callIsValidSignature(hash, abi.encode(uint256(1), bytes(hex"deadbeef")));
        assertFalse(reverted, "passkey co-owner index reachable, no revert");
        assertEq(ret, ERC1271_FAIL, "malformed passkey payload returns failure magic");

        // Removing the primary (index-0) owner is rejected — passkey-only is not a supported model.
        vm.expectRevert(AtomWallet.AtomWallet_OwnerCannotBeRemoved.selector);
        wallet.removeOwnerAtIndex(0, abi.encode(owner));
    }

    /// @dev An out-of-range owner index returns the failure magic non-revertingly (pre-fix this
    ///      reverted for any non-zero index).
    function test_outOfRangeOwnerIndex_returnsFailNonReverting() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("h5-oob");
        resetPrank(warden);
        wallet.completeClaim(owner);

        bytes32 hash = keccak256("oob");
        (bool reverted, bytes4 ret) = _callIsValidSignature(hash, _wrapEoaSig(5, hash, ownerKey));
        assertFalse(reverted, "out-of-range index does not revert");
        assertEq(ret, ERC1271_FAIL, "out-of-range index returns failure magic");
    }

    /// @dev F-002 positive vector: a P-256 / passkey co-owner at index 1 validates a REAL WebAuthn
    ///      signature end-to-end (inline decode -> WebAuthn.verify -> P256), returning the ERC-1271
    ///      magic. This closes the "passkey reachable but not positively validated" gap.
    function test_F002_passkeyCoOwnerValidatesWithRealWebAuthnSignature() public {
        (address owner,) = makeAddrAndKey("h5-pk-owner");
        resetPrank(warden);
        wallet.completeClaim(owner);

        uint256 p256Key = 0xA11CE5;
        (uint256 x, uint256 y) = vm.publicKeyP256(p256Key);
        resetPrank(owner);
        wallet.addOwnerPublicKey(bytes32(x), bytes32(y)); // passkey at index 1

        bytes32 hash = keccak256("passkey-positive");
        bytes memory wrapper = _passkeyWrapper(1, hash, p256Key);
        assertEq(
            wallet.isValidSignature(hash, wrapper), ERC1271_MAGIC, "passkey co-owner@1 validates a real P-256 signature"
        );
    }

    /// @dev F-002 positive combined model: an EOA owner at index 0 and a passkey co-owner at index 1
    ///      both validate real signatures on the same wallet.
    function test_F002_eoaAndPasskey_bothValidateWithRealSignatures() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("h5-combo2-eoa");
        resetPrank(warden);
        wallet.completeClaim(owner);

        uint256 p256Key = 0xB0BCAFE;
        (uint256 x, uint256 y) = vm.publicKeyP256(p256Key);
        resetPrank(owner);
        wallet.addOwnerPublicKey(bytes32(x), bytes32(y)); // passkey at index 1

        bytes32 hash = keccak256("combo-positive");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(0, hash, ownerKey)), ERC1271_MAGIC, "EOA owner@0 validates");
        assertEq(
            wallet.isValidSignature(hash, _passkeyWrapper(1, hash, p256Key)),
            ERC1271_MAGIC,
            "passkey co-owner@1 validates"
        );
    }

    /* =================================================== */
    /*                  DEFENDED NEGATIVES                 */
    /* =================================================== */

    /// @dev Pre-claim the registry is empty; ERC-1271 returns failure for any signature.
    function test_preClaim_isValidSignatureReturnsFail() public view {
        bytes32 hash = keccak256("pre-claim");
        assertEq(wallet.isValidSignature(hash, _wrapEoaSig(0, hash, attackerKey)), ERC1271_FAIL, "pre-claim -> fail");
    }

    /// @dev The claim transition is one-way; a second `completeClaim` reverts.
    function test_doubleCompleteClaim_reverts() public {
        resetPrank(warden);
        wallet.completeClaim(users.alice);

        vm.expectRevert(AtomWallet.AtomWallet_AlreadyClaimed.selector);
        wallet.completeClaim(users.bob);
    }

    /// @dev Pre-claim, a non-owner / non-EntryPoint caller cannot `execute`.
    function test_preClaim_executeRevertsForNonOwner() public {
        vm.startPrank(attacker);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        wallet.execute(attacker, 0, "");
        vm.stopPrank();
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    /// @dev Inline-encoded SignatureWrapper for an EOA owner: abi.encode(ownerIndex, 65-byte sig).
    function _wrapEoaSig(uint256 ownerIndex, bytes32 hash, uint256 key) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        return abi.encode(ownerIndex, abi.encodePacked(r, s, v));
    }

    /// @dev Builds an inline-encoded wrapper carrying a real WebAuthn assertion over `hash` for the
    ///      P-256 key `p256Key`, signed so it passes Solady `WebAuthn.verify` (UP flag set, low-s).
    ///      The clientDataJSON prefix is fixed, so `typeIndex == 1` and `challengeIndex == 23`.
    function _passkeyWrapper(uint256 ownerIndex, bytes32 hash, uint256 p256Key) internal pure returns (bytes memory) {
        // AtomWallet passes `abi.encode(hash)` (the raw 32-byte digest) as the WebAuthn challenge.
        string memory b64 = Base64.encode(abi.encode(hash), true, true);
        string memory clientDataJSON =
            string.concat('{"type":"webauthn.get","challenge":"', b64, '","origin":"https://intuition.systems"}');

        // 32-byte rpIdHash ‖ flags(0x01 = UP set) ‖ 4-byte counter. rpIdHash is not checked by verify.
        bytes memory authenticatorData = abi.encodePacked(bytes32(uint256(0xA11CE)), bytes1(0x01), bytes4(0x00000001));

        bytes32 message = sha256(abi.encodePacked(authenticatorData, sha256(bytes(clientDataJSON))));
        (bytes32 r, bytes32 s) = vm.signP256(p256Key, message);
        if (uint256(s) > P256.N / 2) {
            s = bytes32(P256.N - uint256(s)); // low-s normalization (verify rejects high-s)
        }

        WebAuthn.WebAuthnAuth memory auth = WebAuthn.WebAuthnAuth({
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSON,
            challengeIndex: 23,
            typeIndex: 1,
            r: r,
            s: s
        });
        return abi.encode(ownerIndex, abi.encode(auth));
    }

    /// @dev Calls `isValidSignature` via low-level staticcall so a revert (rather than a returned
    ///      failure magic) is observable as `reverted == true`.
    function _callIsValidSignature(bytes32 hash, bytes memory wrapper)
        internal
        view
        returns (bool reverted, bytes4 ret)
    {
        (bool ok, bytes memory out) = address(wallet)
            .staticcall(abi.encodeCall(wallet.isValidSignature, (hash, wrapper)));
        if (!ok) return (true, bytes4(0));
        return (false, abi.decode(out, (bytes4)));
    }
}
