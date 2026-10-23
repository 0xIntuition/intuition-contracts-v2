// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { CoinbaseSmartWalletLib } from "src/libraries/CoinbaseSmartWalletLib.sol";
import { CoinbaseSmartWalletLibHarness } from "tests/mocks/CoinbaseSmartWalletLibHarness.sol";

/// @dev forge test --match-path 'tests/unit/libraries/CoinbaseSmartWalletLib.t.sol'
/// @notice AtomWallet only ever builds well-formed owner bytes through the library's own
///         `addOwnerAddress` / `addOwnerPublicKey` / `initializeOwners` entrypoints, so several of
///         the library's defensive guards (malformed signature encodings, malformed raw owner
///         bytes, index/owner mismatches) are never exercised through the production call path.
///         This harness calls the library directly to cover them.
contract CoinbaseSmartWalletLibTest is Test {
    CoinbaseSmartWalletLibHarness internal harness;

    function setUp() public {
        harness = new CoinbaseSmartWalletLibHarness();
    }

    /* =================================================== */
    /*              isValidSignature — malformed           */
    /* =================================================== */

    function test_isValidSignature_returnsFalse_whenDataLenExceedsSignatureLength() external view {
        // header-only signature (96 bytes) that claims an absurdly large signatureData length
        bytes memory signature = abi.encodePacked(uint256(0), uint256(64), uint256(type(uint256).max));
        assertFalse(harness.isValidSignature(bytes32(0), signature));
    }

    function test_isValidSignature_returnsFalse_whenSignatureShorterThanPaddedData() external view {
        // claims a 32-byte signatureData but only carries 4 trailing bytes
        bytes memory signature = abi.encodePacked(uint256(0), uint256(64), uint256(32), bytes4(0));
        assertFalse(harness.isValidSignature(bytes32(0), signature));
    }

    /// @dev The only add-paths (`addOwnerAddress` / `initializeOwners`) always validate a 32-byte
    ///      owner encodes a value <= uint160.max, so `isValidSignature`'s own defensive re-check of
    ///      that bound can never fire through any real add path. Directly corrupts the ERC-7201
    ///      owner-storage slot to simulate the state that guard exists to catch, and asserts the
    ///      library fails soft (`false`) rather than reverting.
    function test_isValidSignature_returnsFalse_whenStoredOwnerBytesCorruptedAboveAddressRange() external {
        uint256 ownerAtIndexSlot = uint256(CoinbaseSmartWalletLib.MULTI_OWNABLE_STORAGE_LOCATION) + 2;
        uint256 testIndex = 0;
        bytes32 headerSlot = keccak256(abi.encode(testIndex, ownerAtIndexSlot));
        bytes32 dataSlot = keccak256(abi.encodePacked(headerSlot));

        // Long-bytes encoding: header holds `length * 2 + 1`; the 32-byte payload lives at
        // keccak256(headerSlot).
        vm.store(address(harness), headerSlot, bytes32(uint256(32 * 2 + 1)));
        vm.store(address(harness), dataSlot, bytes32(type(uint256).max));

        assertEq(harness.ownerAtIndex(testIndex).length, 32, "sanity: corrupted owner visible at index 0");

        bytes memory signature = abi.encode(uint256(testIndex), bytes(""));
        assertFalse(harness.isValidSignature(bytes32(0), signature));
    }

    /* =================================================== */
    /*                 initializeOwners guards              */
    /* =================================================== */

    function test_initializeOwners_revertsOnInvalidLength() external {
        bytes[] memory owners = new bytes[](1);
        owners[0] = new bytes(10);

        vm.expectRevert(abi.encodeWithSelector(CoinbaseSmartWalletLib.InvalidOwnerBytesLength.selector, owners[0]));
        harness.initializeOwners(owners);
    }

    function test_initializeOwners_revertsOnAddressOverflow() external {
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encodePacked(bytes32(type(uint256).max));

        vm.expectRevert(abi.encodeWithSelector(CoinbaseSmartWalletLib.InvalidEthereumAddressOwner.selector, owners[0]));
        harness.initializeOwners(owners);
    }

    /* =================================================== */
    /*                 owner removal guards                 */
    /* =================================================== */

    function test_removeOwnerAtIndex_revertsOnLastOwner() external {
        bytes memory ownerBytes = abi.encode(address(0x1111));
        bytes[] memory owners = new bytes[](1);
        owners[0] = ownerBytes;
        harness.initializeOwners(owners);

        vm.expectRevert(CoinbaseSmartWalletLib.LastOwner.selector);
        harness.removeOwnerAtIndex(0, ownerBytes);
    }

    function test_removeLastOwner_revertsWhenMoreThanOneRemains() external {
        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encode(address(0x1111));
        owners[1] = abi.encode(address(0x2222));
        harness.initializeOwners(owners);

        vm.expectRevert(abi.encodeWithSelector(CoinbaseSmartWalletLib.NotLastOwner.selector, 2));
        harness.removeLastOwner(0, owners[0]);
    }

    function test_removeOwnerAtIndex_revertsOnEmptyIndex() external {
        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encode(address(0x1111));
        owners[1] = abi.encode(address(0x2222));
        harness.initializeOwners(owners);

        vm.expectRevert(abi.encodeWithSelector(CoinbaseSmartWalletLib.NoOwnerAtIndex.selector, 99));
        harness.removeOwnerAtIndex(99, owners[0]);
    }

    function test_removeOwnerAtIndex_revertsOnMismatchedOwner() external {
        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encode(address(0x1111));
        owners[1] = abi.encode(address(0x2222));
        harness.initializeOwners(owners);

        bytes memory wrong = abi.encode(address(0x9999));
        vm.expectRevert(abi.encodeWithSelector(CoinbaseSmartWalletLib.WrongOwnerAtIndex.selector, 0, wrong, owners[0]));
        harness.removeOwnerAtIndex(0, wrong);
    }

    /* =================================================== */
    /*                     add-owner guards                 */
    /* =================================================== */

    function test_addOwnerAddress_revertsOnDuplicate() external {
        harness.addOwnerAddress(address(0x3333));

        bytes memory dup = abi.encode(address(0x3333));
        vm.expectRevert(abi.encodeWithSelector(CoinbaseSmartWalletLib.AlreadyOwner.selector, dup));
        harness.addOwnerAddress(address(0x3333));
    }

    /* =================================================== */
    /*                 removal bookkeeping                  */
    /* =================================================== */

    function test_removedOwnersCount_incrementsOnRemoval() external {
        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encode(address(0x1111));
        owners[1] = abi.encode(address(0x2222));
        harness.initializeOwners(owners);

        assertEq(harness.removedOwnersCount(), 0);

        harness.removeOwnerAtIndex(0, owners[0]);
        assertEq(harness.removedOwnersCount(), 1);
    }

    /* =================================================== */
    /*                  EIP-712 replay-safe hash            */
    /* =================================================== */

    function test_replaySafeHash_matchesManualDomainSeparatorComputation() external view {
        bytes32 hash = keccak256("test message");
        string memory name = "AtomWallet";
        string memory version = "1";

        bytes32 domainSeparator = harness.domainSeparator(name, version);
        bytes32 expected = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(keccak256("CoinbaseSmartWalletMessage(bytes32 hash)"), hash))
            )
        );

        assertEq(harness.replaySafeHash(hash, name, version), expected);
    }

    function test_domainSeparator_changesWithChainId() external {
        bytes32 before = harness.domainSeparator("AtomWallet", "1");

        vm.chainId(block.chainid + 1);
        bytes32 afterChainChange = harness.domainSeparator("AtomWallet", "1");

        assertNotEq(before, afterChainChange);
    }
}
