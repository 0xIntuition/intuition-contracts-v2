// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {AtomWalletFactory} from "src/v2/AtomWalletFactory.sol";
import {BondingCurveRegistry} from "src/curves/BondingCurveRegistry.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {
    IMultiVaultConfig,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig,
    WrapperConfig
} from "src/interfaces/IMultiVaultConfig.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {LinearCurve} from "src/curves/LinearCurve.sol";
import {MultiVault} from "src/MultiVault.sol";
import {MultiVaultConfig} from "src/v2/MultiVaultConfig.sol";
import {OffsetProgressiveCurve} from "src/curves/OffsetProgressiveCurve.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";
import {TrustVestedMerkleDistributor} from "src/v2/TrustVestedMerkleDistributor.sol";

import {MockTrust} from "test/mocks/MockTrust.t.sol";

contract DeployV2ToMainnet is Script {
    /// @notice Custom errors
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        // Allow the script to run only on Base Mainnet to prevent accidental deployments on Base Sepolia
        if (block.chainid != 8453) {
            revert UnsupportedChainId();
        }

        vm.stopBroadcast();
    }
}
