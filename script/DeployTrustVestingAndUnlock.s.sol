// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";

import {TrustVestingAndUnlock} from "src/v2/TrustVestingAndUnlock.sol";

contract DeployTrustVestingAndUnlock is Script {
    /// @notice Deployed Trust token address on Base
    address public trustTokenAddress = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    /// @notice Admin of the TrustVestingAndUnlock contract (can set TrustBonding address and TGE timestamp)
    address public admin;

    /// @notice Deployed TrustBonding contract address on Base
    address public trustBondingAddress;

    // TrustVestingAndUnlock parameters (specific for each recipient)
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

        console.log("TrustUnlock address: ", address(trustVestingAndUnlock));

        vm.stopBroadcast();
    }
}
