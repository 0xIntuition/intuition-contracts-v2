// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { CoinbaseSmartWalletLib } from "src/libraries/CoinbaseSmartWalletLib.sol";

/**
 * @title CoinbaseSmartWalletLibHarness
 * @notice Exposes CoinbaseSmartWalletLib's internal functions for direct unit testing, since the
 *         library has no state of its own and every real caller (AtomWallet) always builds
 *         well-formed owner bytes, leaving several of the library's own defensive guards
 *         unreachable through the production call path.
 */
contract CoinbaseSmartWalletLibHarness {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bool) {
        return CoinbaseSmartWalletLib.isValidSignature(hash, signature);
    }

    function initializeOwners(bytes[] memory owners) external {
        CoinbaseSmartWalletLib.initializeOwners(owners);
    }

    function addOwnerAddress(address owner) external {
        CoinbaseSmartWalletLib.addOwnerAddress(owner);
    }

    function addOwnerPublicKey(bytes32 x, bytes32 y) external {
        CoinbaseSmartWalletLib.addOwnerPublicKey(x, y);
    }

    function removeOwnerAtIndex(uint256 index, bytes calldata owner) external {
        CoinbaseSmartWalletLib.removeOwnerAtIndex(index, owner);
    }

    function removeLastOwner(uint256 index, bytes calldata owner) external {
        CoinbaseSmartWalletLib.removeLastOwner(index, owner);
    }

    function removeOwnerByAddress(address owner) external {
        CoinbaseSmartWalletLib.removeOwnerByAddress(owner);
    }

    function isOwnerAddress(address account) external view returns (bool) {
        return CoinbaseSmartWalletLib.isOwnerAddress(account);
    }

    function isOwnerPublicKey(bytes32 x, bytes32 y) external view returns (bool) {
        return CoinbaseSmartWalletLib.isOwnerPublicKey(x, y);
    }

    function isOwnerBytes(bytes memory account) external view returns (bool) {
        return CoinbaseSmartWalletLib.isOwnerBytes(account);
    }

    function ownerAtIndex(uint256 index) external view returns (bytes memory) {
        return CoinbaseSmartWalletLib.ownerAtIndex(index);
    }

    function ownerCount() external view returns (uint256) {
        return CoinbaseSmartWalletLib.ownerCount();
    }

    function nextOwnerIndex() external view returns (uint256) {
        return CoinbaseSmartWalletLib.nextOwnerIndex();
    }

    function removedOwnersCount() external view returns (uint256) {
        return CoinbaseSmartWalletLib.removedOwnersCount();
    }

    function replaySafeHash(bytes32 hash, string memory name, string memory version) external view returns (bytes32) {
        return CoinbaseSmartWalletLib.replaySafeHash(hash, name, version);
    }

    function domainSeparator(string memory name, string memory version) external view returns (bytes32) {
        return CoinbaseSmartWalletLib.domainSeparator(name, version);
    }
}
