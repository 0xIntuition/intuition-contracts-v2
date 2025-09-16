// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

/**
 * @title  TrustUnlock
 * @author 0xIntuition
 * @notice Minimal interface for the TrustUnlock factory (registry)
 */
interface ITrustUnlockFactory {
    function trustToken() external view returns (address payable);
    function trustBonding() external view returns (address);
    function multiVault() external view returns (address payable);
}
