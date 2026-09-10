// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";

/// @title  AtomWalletSignatureBindingTest
/// @notice Negative regressions on the ERC-1271 surface: the properties that must FAIL, which the
///         existing positive-path coverage cannot express.
///
///         The existing wallet suite asserts that a correctly enveloped signature is ACCEPTED. That
///         leaves the replay-safe binding protected against deletion but not against a permissive
///         change — one accepting either the envelope or the bare digest, which is the shape a
///         "keep old signatures working" refactor takes. These tests assert the rejections directly:
///           - a signature over the BARE digest must not validate;
///           - a wrapper whose encoded length carries trailing bytes must not validate.
contract AtomWalletSignatureBindingTest is BaseTest {
    AtomWallet internal wallet;
    address internal warden;
    uint256 internal ownerKey;
    address internal ownerAddr;

    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_INVALID = 0xffffffff;

    function setUp() public override {
        super.setUp();

        (ownerAddr, ownerKey) = makeAddrAndKey("sig-binding-owner");
        warden = protocol.multiVault.getAtomWarden();

        bytes32 atomId = createSimpleAtom("sig-binding", ATOM_COST[0], users.alice);
        wallet = AtomWallet(payable(protocol.atomWalletFactory.deployAtomWallet(atomId)));

        resetPrank(warden);
        wallet.completeClaim(ownerAddr);
    }

    /// @dev Build the wrapper the wallet expects: `abi.encode(ownerIndex, signatureData)`.
    function _wrap(uint256 ownerIndex, bytes memory sig) internal pure returns (bytes memory) {
        return abi.encode(ownerIndex, sig);
    }

    /// @dev Reconstructs the wallet-bound EIP-712 digest. `verifyingContract` is the WALLET, which is
    ///      exactly the binding under test — reconstructing it here rather than calling the library
    ///      keeps the test independent of the implementation it is asserting against.
    function _replaySafeHash(address forWallet, bytes32 hash) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("AtomWallet")),
                keccak256(bytes("1")),
                block.chainid,
                forWallet
            )
        );
        bytes32 messageHash = keccak256(abi.encode(keccak256("CoinbaseSmartWalletMessage(bytes32 hash)"), hash));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));
    }

    function _sign(uint256 key, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Control: the correctly bound signature is accepted. If this fails the fixture is wrong,
    ///      and the negative assertions below would be vacuous.
    function test_isValidSignature_acceptsReplaySafeEnvelope() external {
        bytes32 rawDigest = keccak256("intuition-erc1271-binding");
        bytes32 bound = _replaySafeHash(address(wallet), rawDigest);

        bytes memory sig = _wrap(0, _sign(ownerKey, bound));
        assertEq(wallet.isValidSignature(rawDigest, sig), ERC1271_MAGIC_VALUE, "enveloped signature must validate");
    }

    /// @dev A signature over the RAW, unbound digest must be rejected. This is the assertion that goes
    ///      red under a permissive change accepting either form — the case the positive-path tests miss.
    function test_isValidSignature_rejectsBareUnboundDigest() external {
        bytes32 rawDigest = keccak256("intuition-erc1271-binding");

        bytes memory sig = _wrap(0, _sign(ownerKey, rawDigest));
        assertEq(
            wallet.isValidSignature(rawDigest, sig),
            ERC1271_INVALID,
            "a signature over the unbound digest must NOT validate"
        );
    }

    /// @dev The wrapper encoding is canonical: trailing bytes past the encoded payload must be
    ///      rejected rather than ignored, so one authorization maps to exactly one byte string.
    function test_isValidSignature_rejectsTrailingPaddedWrapper() external {
        bytes32 rawDigest = keccak256("intuition-erc1271-binding");
        bytes32 bound = _replaySafeHash(address(wallet), rawDigest);

        bytes memory canonical = _wrap(0, _sign(ownerKey, bound));
        assertEq(wallet.isValidSignature(rawDigest, canonical), ERC1271_MAGIC_VALUE, "control must validate");

        bytes memory padded = bytes.concat(canonical, hex"00");
        assertEq(
            wallet.isValidSignature(rawDigest, padded), ERC1271_INVALID, "a trailing-padded wrapper must NOT validate"
        );

        bytes memory paddedWide = bytes.concat(canonical, new bytes(32));
        assertEq(
            wallet.isValidSignature(rawDigest, paddedWide), ERC1271_INVALID, "a word-padded wrapper must NOT validate"
        );
    }

    /// @dev The binding is per-wallet: a signature valid for this wallet must not validate on another.
    function test_isValidSignature_rejectsCrossWalletReplay() external {
        bytes32 rawDigest = keccak256("intuition-erc1271-binding");
        bytes32 bound = _replaySafeHash(address(wallet), rawDigest);
        bytes memory sig = _wrap(0, _sign(ownerKey, bound));

        bytes32 otherAtom = createSimpleAtom("sig-binding-other", ATOM_COST[0], users.alice);
        AtomWallet other = AtomWallet(payable(protocol.atomWalletFactory.deployAtomWallet(otherAtom)));

        resetPrank(warden);
        other.completeClaim(ownerAddr);

        assertEq(other.isValidSignature(rawDigest, sig), ERC1271_INVALID, "signature must not replay to another wallet");
    }
}
