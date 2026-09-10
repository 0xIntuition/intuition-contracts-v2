// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { SetupScript } from "script/SetupScript.s.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";

/*
MAINNET (Intuition)
forge script script/intuition/DeployCoreUpgradeImplementations.s.sol:DeployCoreUpgradeImplementations \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract DeployCoreUpgradeImplementations is SetupScript {
    error UnsupportedChain();

    /// @dev Mainnet proxy addresses (Intuition, chain 1155)
    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant MULTIVAULT_PROXY_ADMIN = 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8;
    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant TRUST_BONDING_PROXY_ADMIN = 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62;
    address internal constant OFFSET_CURVE_PROXY = 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d;
    address internal constant OFFSET_CURVE_PROXY_ADMIN = 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7;
    address internal constant ATOM_WARDEN_PROXY = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;
    address internal constant ATOM_WARDEN_PROXY_ADMIN = 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A;
    address internal constant ATOM_WALLET_BEACON = 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF;
    address internal constant SATELLITE_EC_PROXY = 0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6;
    address internal constant SATELLITE_EC_PROXY_ADMIN = 0xdF60D18E86F3454309aD7734055843F7ee5f30a3;

    MultiVault public multiVaultImplementation;
    TrustBonding public trustBondingImplementation;
    OffsetProgressiveCurve public offsetProgressiveCurveImplementation;
    AtomWarden public atomWardenImplementation;
    AtomWallet public atomWalletImpl;
    SatelliteEmissionsController public satelliteEmissionsControllerImplementation;

    function setUp() public override {
        super.setUp();

        if (block.chainid != NETWORK_INTUITION) {
            revert UnsupportedChain();
        }
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        _deployImplementations();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("MultiVault Implementation", address(multiVaultImplementation));
        contractInfo("TrustBonding Implementation", address(trustBondingImplementation));
        contractInfo("OffsetProgressiveCurve Implementation", address(offsetProgressiveCurveImplementation));
        contractInfo("AtomWarden Implementation", address(atomWardenImplementation));
        contractInfo("AtomWallet Implementation", address(atomWalletImpl));
        contractInfo("SatelliteEmissionsController Implementation", address(satelliteEmissionsControllerImplementation));

        _logUpgradeCalldata();
    }

    function _deployImplementations() internal {
        multiVaultImplementation = new MultiVault();
        info("MultiVault Implementation", address(multiVaultImplementation));

        trustBondingImplementation = new TrustBonding();
        info("TrustBonding Implementation", address(trustBondingImplementation));

        offsetProgressiveCurveImplementation = new OffsetProgressiveCurve();
        info("OffsetProgressiveCurve Implementation", address(offsetProgressiveCurveImplementation));

        atomWardenImplementation = new AtomWarden();
        info("AtomWarden Implementation", address(atomWardenImplementation));

        atomWalletImpl = new AtomWallet();
        info("AtomWallet Implementation", address(atomWalletImpl));

        satelliteEmissionsControllerImplementation = new SatelliteEmissionsController();
        info("SatelliteEmissionsController Implementation", address(satelliteEmissionsControllerImplementation));
    }

    /// @dev Logs the encoded calldata for each timelock-scheduled upgrade operation.
    ///      Use these as the `data` parameter when calling TimelockController.schedule().
    function _logUpgradeCalldata() internal view {
        console2.log("");
        console2.log("UPGRADE CALLDATA: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        // ProxyAdmin.upgradeAndCall(proxy, newImpl, 0x) for each TransparentUpgradeableProxy
        console2.log("");
        console2.log("MultiVault upgrade (target: ProxyAdmin %s):", MULTIVAULT_PROXY_ADMIN);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(MULTIVAULT_PROXY), address(multiVaultImplementation), "")
            )
        );

        console2.log("");
        console2.log("TrustBonding upgrade (target: ProxyAdmin %s):", TRUST_BONDING_PROXY_ADMIN);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(TRUST_BONDING_PROXY), address(trustBondingImplementation), "")
            )
        );

        console2.log("");
        console2.log("OffsetProgressiveCurve upgrade (target: ProxyAdmin %s):", OFFSET_CURVE_PROXY_ADMIN);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(OFFSET_CURVE_PROXY), address(offsetProgressiveCurveImplementation), "")
            )
        );

        // AtomWarden uses a two-step flow because `reinitialize` is gated to the
        // MultiVault-resolved admin, and a single-tx `upgradeAndCall` would arrive
        // at the impl with `msg.sender == ProxyAdmin`. STEP 1 is the bare proxy
        // upgrade submitted by the timelock; STEP 2 is `reinitialize(...)`
        // submitted by the MultiVault admin directly against the proxy.
        console2.log("");
        console2.log("AtomWarden upgrade STEP 1 (target: ProxyAdmin %s):", ATOM_WARDEN_PROXY_ADMIN);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(ATOM_WARDEN_PROXY), address(atomWardenImplementation), "")
            )
        );

        console2.log("");
        console2.log(
            "AtomWarden upgrade STEP 2 (target: AtomWarden proxy %s, sender: MultiVault admin):", ATOM_WARDEN_PROXY
        );
        console2.log(
            "        Pass operational claimWindow / minFeeThreshold / signatureThreshold / maxValidAfter / maxValidUntil / maxClaimsPerWindow / claimCapWindow."
        );
        console2.log("        Defaults below mirror IntuitionDeployAndSetup parity values; admin can");
        console2.log("        rotate via setClaimWindow / setMinFeeThreshold / setSignatureThreshold /");
        console2.log("        setMaxValidAfter / setMaxValidUntil / setMaxClaimsPerWindow / setClaimCapWindow.");
        console2.log("        maxClaimsPerWindow = 0 ships the authorized-claim cap disabled; arm it");
        console2.log("        deliberately via setMaxClaimsPerWindow once a budget is chosen.");
        console2.logBytes(
            abi.encodeCall(
                AtomWarden.reinitialize,
                (
                    uint256(365 days),
                    uint256(0),
                    uint256(1),
                    uint48(1 hours),
                    uint48(1 days),
                    uint256(0),
                    uint256(1 days)
                )
            )
        );

        console2.log("");
        console2.log("SatelliteEmissionsController upgrade (target: ProxyAdmin %s):", SATELLITE_EC_PROXY_ADMIN);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (
                    ITransparentUpgradeableProxy(SATELLITE_EC_PROXY),
                    address(satelliteEmissionsControllerImplementation),
                    ""
                )
            )
        );

        // UpgradeableBeacon.upgradeTo(newImpl) for AtomWalletBeacon
        console2.log("");
        console2.log("AtomWallet beacon upgrade (target: Beacon %s):", ATOM_WALLET_BEACON);
        console2.logBytes(abi.encodeCall(UpgradeableBeacon.upgradeTo, (address(atomWalletImpl))));
    }
}
