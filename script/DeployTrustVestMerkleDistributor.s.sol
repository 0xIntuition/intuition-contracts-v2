// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {TrustVestedMerkleDistributor} from "src/v2/TrustVestedMerkleDistributor.sol";

contract DeployV2ToMainnet is Script {
    /// @notice Constants
    uint256 public constant ONE_MONTH = 30 * 24 * 60 * 60;
    address public admin = vm.envAddress("ADMIN");
    address public trustTokenAddress = vm.envAddress("TRUST_TOKEN_ADDRESS");
    address public trustBondingAddress = vm.envAddress("TRUST_BONDING_ADDRESS");

    /// @notice Params (replace here as needed before the deployment)
    uint256 public feeInBPS = 0;
    uint256 public vestingStartTimestamp = block.timestamp + ONE_MONTH; // vesting starts 1 month from deployment
    uint256 public vestingDuration = 6 * ONE_MONTH; // vesting duration is 6 months
    uint256 public claimEndTimestamp = block.timestamp + (10 * ONE_MONTH); // claim period lasts for 3 extra months after vesting ends
    uint256 public tgeBPS = 5000; // 50% claimable at TGE
    uint256 public rageQuitBPS = 6500; // 65% claimable instantly if rage quitting
    bytes32 public merkleRoot; // NOTE: Replace with the actual Merkle root before deploying

    /// @notice Core contracts
    TrustVestedMerkleDistributor public trustVestedMerkleDistributor;

    /// @notice Custom errors
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        // Allow the script to run only on Base Mainnet to prevent accidental deployments on Base Sepolia
        if (block.chainid != 8453) {
            revert UnsupportedChainId();
        }

        // deploy the TrustVestedMerkleDistributor implementation contract
        trustVestedMerkleDistributor = new TrustVestedMerkleDistributor();
        console.log("TrustVestedMerkleDistributor implementation address: ", address(trustVestedMerkleDistributor));

        // deploy the TrustVestedMerkleDistributor proxy contract
        TransparentUpgradeableProxy trustVestedMerkleDistributorProxy =
            new TransparentUpgradeableProxy(address(trustVestedMerkleDistributor), admin, "");

        trustVestedMerkleDistributor = TrustVestedMerkleDistributor(address(trustVestedMerkleDistributorProxy));
        console.log("TrustVestedMerkleDistributor proxy address: ", address(trustVestedMerkleDistributorProxy));

        // initialize the TrustVestedMerkleDistributor contract
        TrustVestedMerkleDistributor.VestingParams memory distributorVestingParams = TrustVestedMerkleDistributor
            .VestingParams({
            owner: admin,
            trust: trustTokenAddress,
            trustBonding: trustBondingAddress,
            protocolTreasury: admin,
            feeInBPS: feeInBPS,
            vestingStartTimestamp: vestingStartTimestamp,
            vestingDuration: vestingDuration,
            claimEndTimestamp: claimEndTimestamp,
            tgeBPS: tgeBPS,
            rageQuitBPS: rageQuitBPS,
            merkleRoot: merkleRoot
        });

        trustVestedMerkleDistributor.initialize(distributorVestingParams);

        // NOTE: Add the merkle distributor contract to the whitelist for the TrustBonding contract
        // Call from the admin Safe: trustBonding.add_to_whitelist(address(trustVestedMerkleDistributor));

        vm.stopBroadcast();
    }
}
