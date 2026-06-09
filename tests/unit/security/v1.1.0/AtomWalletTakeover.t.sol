// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";

/// @title  Track 5 — AtomWallet takeover / permanent-DoS hunt (ENG-12460)
/// @notice Attempts a permissionless takeover of an AtomWallet: passing signature
///         validation without being an owner (pre-claim, when the MultiOwnable
///         registry is empty), seeding an owner without the warden, and adding /
///         removing owners without authorization. All NEGATIVE results.
///
///         Complements tests/unit/AtomWallet/AtomWallet.t.sol (completeClaim +
///         owner-function access control) with the pre-claim signature-bypass and
///         primary-owner-lockout angles.
contract AtomWalletTakeoverTest is BaseTest {
    bytes4 internal constant ERC1271_MAGIC = 0x1626ba7e;
    bytes4 internal constant ERC1271_FAIL = 0xffffffff;

    AtomWallet internal wallet;
    address internal warden;
    address internal attacker;
    uint256 internal attackerKey = 0xA77ACC;

    function setUp() public override {
        super.setUp();
        warden = protocol.multiVault.getAtomWarden(); // address(1) per BaseTest config
        attacker = vm.addr(attackerKey);

        bytes32 atomId = createSimpleAtom("t5-wallet", ATOM_COST[0], users.alice);

        address walletAddr = protocol.atomWalletFactory.deployAtomWallet(atomId);
        wallet = AtomWallet(payable(walletAddr));
    }

    /// @dev H1: while the wallet is unclaimed the MultiOwnable registry is empty, so
    ///      ERC-1271 must reject EVERY signature — no permissionless takeover via a
    ///      forged owner signature before the warden hands ownership over.
    function test_preClaim_isValidSignature_rejectsForgedSig() public view {
        bytes32 hash = keccak256("take-over-me");

        // A well-formed SignatureWrapper(ownerIndex=0, attacker ECDSA sig). With an
        // empty registry, ownerAtIndex[0] is empty ⇒ validation returns false.
        bytes memory wrapper = _wrapEoaSig(0, hash, attackerKey);
        assertEq(wallet.isValidSignature(hash, wrapper), ERC1271_FAIL, "forged wrapper rejected pre-claim");
    }

    /// @dev Malformed signature bytes must return the failure magic value, never
    ///      revert and never the success magic — a robust non-reverting reject.
    function test_preClaim_isValidSignature_malformedReturnsFail() public view {
        bytes32 hash = keccak256("malformed");
        assertEq(wallet.isValidSignature(hash, hex"00"), ERC1271_FAIL, "short bytes -> fail");
        assertEq(wallet.isValidSignature(hash, new bytes(96)), ERC1271_FAIL, "zero wrapper -> fail");
        assertEq(wallet.isValidSignature(hash, hex"deadbeef"), ERC1271_FAIL, "garbage -> fail");
    }

    /// @dev H2: a permissionless actor cannot seed itself as owner via completeClaim —
    ///      only the warden may. No takeover of an unclaimed wallet.
    function test_nonWarden_cannotCompleteClaim() public {
        vm.startPrank(attacker);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyAtomWarden.selector);
        wallet.completeClaim(attacker);
        vm.stopPrank();
    }

    /// @dev H3: after a legitimate claim, a non-owner still cannot add an owner.
    function test_nonOwner_cannotAddOwner_afterClaim() public {
        vm.startPrank(warden);
        wallet.completeClaim(users.alice);

        vm.startPrank(attacker);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwner.selector);
        wallet.addOwnerAddress(attacker);
        vm.stopPrank();
    }

    /// @dev H4: the primary owner cannot be removed — blocks the owner-lockout DoS.
    function test_cannotRemovePrimaryOwner_afterClaim() public {
        vm.startPrank(warden);
        wallet.completeClaim(users.alice);

        // owner() resolves to the claimant (alice) at index 0 in the registry.
        bytes memory ownerBytes = abi.encode(wallet.owner());
        vm.startPrank(users.alice);
        vm.expectRevert(AtomWallet.AtomWallet_OwnerCannotBeRemoved.selector);
        wallet.removeOwnerAtIndex(0, ownerBytes);
        vm.stopPrank();
    }

    /// @dev Post-claim, the rightful owner's signature validates via ERC-1271 — the
    ///      positive control proving the pre-claim rejection is about ownership, not
    ///      a broken verifier.
    function test_postClaim_ownerSignatureValidates() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("t5-owner");
        vm.startPrank(warden);
        wallet.completeClaim(owner);

        bytes32 hash = keccak256("legit");
        bytes memory wrapper = _wrapEoaSig(0, hash, ownerKey);
        assertEq(wallet.isValidSignature(hash, wrapper), ERC1271_MAGIC, "owner sig validates post-claim");
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    /// @dev Build a CoinbaseSmartWallet SignatureWrapper for an EOA owner:
    ///      abi.encode(uint256 ownerIndex, bytes signatureData) where signatureData
    ///      is a 65-byte ECDSA signature over `hash`.
    function _wrapEoaSig(uint256 ownerIndex, bytes32 hash, uint256 key) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory sigData = abi.encodePacked(r, s, v);
        return abi.encode(ownerIndex, sigData);
    }
}
