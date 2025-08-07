// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";

import {TrustVestingAndUnlock} from "src/v2/TrustVestingAndUnlock.sol";

contract DeployTrustVestingAndUnlock is Script {
    /// @notice Constants
    address public trustTokenAddress = vm.envAddress("TRUST_TOKEN_ADDRESS");
    address public admin = vm.envAddress("ADMIN");
    address public trustBondingAddress = vm.envAddress("TRUST_BONDING_ADDRESS");
    address public multiVaultAddress = vm.envAddress("MULTI_VAULT_ADDRESS");

    /// @notice TrustVestingAndUnlock parameters (specific for each recipient)
    address public recipient;
    uint256 public vestingAmount;
    uint256 public vestingBegin;
    uint256 public vestingCliff;
    uint256 public cliffPercentage;
    uint256 public vestingEnd;
    uint256 public unlockCliff;
    uint256 public unlockDuration;
    uint256 public unlockCliffPercentage;

    /// @notice TrustVestingAndUnlock contract to be deployed
    TrustVestingAndUnlock public trustVestingAndUnlock;

    /// @notice TrustVestingAndUnlock vesting parameters struct for the contract constructor
    TrustVestingAndUnlock.VestingParams public vestingParams;

    function run() external {
        vm.startBroadcast();

        vestingParams = TrustVestingAndUnlock.VestingParams({
            trustToken: trustTokenAddress,
            recipient: recipient,
            admin: admin,
            trustBonding: trustBondingAddress,
            multiVault: multiVaultAddress,
            vestingAmount: vestingAmount,
            vestingBegin: vestingBegin,
            vestingCliff: vestingCliff,
            cliffPercentage: cliffPercentage,
            vestingEnd: vestingEnd,
            unlockCliff: unlockCliff,
            unlockDuration: unlockDuration,
            unlockCliffPercentage: unlockCliffPercentage
        });

        trustVestingAndUnlock = new TrustVestingAndUnlock(vestingParams);

        console.log("TrustVestingAndUnlock address: ", address(trustVestingAndUnlock));

        // NOTE: Add the TrustVestingAndUnlock contract to the whitelist for the TrustBonding contract
        // Call from the admin Safe: trustBonding.add_to_whitelist(address(trustVestingAndUnlock));

        vm.stopBroadcast();
    }
}
