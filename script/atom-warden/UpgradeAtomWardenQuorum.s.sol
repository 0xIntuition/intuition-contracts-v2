// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";

/*
 * Deploys the quorum-enabled AtomWarden implementation. Does NOT upgrade the
 * proxy — that step is multisig-driven. The script prints two pieces of calldata
 * for the operator to submit:
 *
 *   (1) `ProxyAdmin.upgradeAndCall(proxy, impl, "")` — bare upgrade, no init call.
 *       Submitted through the upgrades-timelock multisig because the proxy admin
 *       is the timelock controller.
 *
 *   (2) `AtomWarden.reinitialize(claimWindow, minFeeThreshold, signatureThreshold)`
 *       — submitted by the MultiVault-resolved admin (the same admin granted on
 *       AtomWarden in v1 initialize). The reinitialize is gated to that admin,
 *       so this MUST be a separate tx from the proxy admin path.
 *
 * Override the reinit args via env when iterating; defaults mirror the
 * IntuitionDeployAndSetup values.
 *
 * INTUITION MAINNET (chain 1155)
 *   forge script script/atom-warden/UpgradeAtomWardenQuorum.s.sol:UpgradeAtomWardenQuorum \
 *     --optimizer-runs 10000 \
 *     --rpc-url intuition \
 *     --broadcast \
 *     --slow \
 *     --verify \
 *     --chain 1155 \
 *     --verifier blockscout \
 *     --verifier-url 'https://intuition.calderaexplorer.xyz/api/'
 *
 * INTUITION SEPOLIA (chain 13579) — addresses are env-supplied since the
 *   testnet proxy locations rotate during the rollout window.
 *   ATOM_WARDEN_PROXY=0x... \
 *   ATOM_WARDEN_PROXY_ADMIN=0x... \
 *   forge script script/atom-warden/UpgradeAtomWardenQuorum.s.sol:UpgradeAtomWardenQuorum \
 *     --rpc-url intuition_sepolia --broadcast --slow --verify --chain 13579
 */
contract UpgradeAtomWardenQuorum is SetupScript {
    error UnsupportedChain();

    /// @dev Intuition mainnet (chain 1155). Mirrors the addresses pinned in
    ///      `script/intuition/DeployCoreUpgradeImplementations.s.sol`.
    address internal constant ATOM_WARDEN_PROXY_MAINNET = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;
    address internal constant ATOM_WARDEN_PROXY_ADMIN_MAINNET = 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A;

    /// @dev Reinitialize defaults. Mirror the IntuitionDeployAndSetup config so
    ///      the upgrade lands at a known-good baseline; admin can rotate via the
    ///      regular setters after reinitialize.
    uint256 internal constant DEFAULT_CLAIM_WINDOW = 365 days;
    uint256 internal constant DEFAULT_MIN_FEE_THRESHOLD = 0;
    uint256 internal constant DEFAULT_SIGNATURE_THRESHOLD = 1;
    uint48 internal constant DEFAULT_MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant DEFAULT_MAX_VALID_UNTIL = uint48(1 days);

    address public atomWardenProxy;
    address public atomWardenProxyAdmin;
    AtomWarden public atomWardenImplementation;

    uint256 internal reinitClaimWindow;
    uint256 internal reinitMinFeeThreshold;
    uint256 internal reinitSignatureThreshold;
    uint48 internal reinitMaxValidAfter;
    uint48 internal reinitMaxValidUntil;

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_INTUITION) {
            atomWardenProxy = ATOM_WARDEN_PROXY_MAINNET;
            atomWardenProxyAdmin = ATOM_WARDEN_PROXY_ADMIN_MAINNET;
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA || block.chainid == NETWORK_ANVIL) {
            atomWardenProxy = vm.envAddress("ATOM_WARDEN_PROXY");
            atomWardenProxyAdmin = vm.envAddress("ATOM_WARDEN_PROXY_ADMIN");
        } else {
            revert UnsupportedChain();
        }

        reinitClaimWindow = vm.envOr("ATOM_WARDEN_CLAIM_WINDOW", DEFAULT_CLAIM_WINDOW);
        reinitMinFeeThreshold = vm.envOr("ATOM_WARDEN_MIN_FEE_THRESHOLD", DEFAULT_MIN_FEE_THRESHOLD);
        reinitSignatureThreshold = vm.envOr("ATOM_WARDEN_SIGNATURE_THRESHOLD", DEFAULT_SIGNATURE_THRESHOLD);
        // forge-lint: disable-next-line(unsafe-typecast)
        reinitMaxValidAfter = uint48(vm.envOr("ATOM_WARDEN_MAX_VALID_AFTER", uint256(DEFAULT_MAX_VALID_AFTER)));
        // forge-lint: disable-next-line(unsafe-typecast)
        reinitMaxValidUntil = uint48(vm.envOr("ATOM_WARDEN_MAX_VALID_UNTIL", uint256(DEFAULT_MAX_VALID_UNTIL)));
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYING ATOMWARDEN IMPLEMENTATION =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        atomWardenImplementation = new AtomWarden();
        info("AtomWarden Implementation", address(atomWardenImplementation));

        _logUpgradeCalldata();
    }

    /// @dev Prints the ABI-encoded calldata for the two-step upgrade flow:
    ///      (1) The bare proxy upgrade — submitted by the proxy admin (timelock).
    ///      (2) The reinitialize call — submitted by the MultiVault-resolved admin
    ///          directly against the proxy, because `reinitialize` is gated to
    ///          that admin (msg.sender check) and a single-tx upgradeAndCall
    ///          would arrive with msg.sender == ProxyAdmin.
    function _logUpgradeCalldata() internal view {
        console2.log("");
        console2.log("UPGRADE CALLDATA: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("AtomWarden Proxy", atomWardenProxy);
        contractInfo("AtomWarden ProxyAdmin (target)", atomWardenProxyAdmin);
        info("Reinit claimWindow", reinitClaimWindow);
        info("Reinit minFeeThreshold", reinitMinFeeThreshold);
        info("Reinit signatureThreshold", reinitSignatureThreshold);
        info("Reinit maxValidAfter", uint256(reinitMaxValidAfter));
        info("Reinit maxValidUntil", uint256(reinitMaxValidUntil));

        console2.log("");
        console2.log("STEP 1 - ProxyAdmin.upgradeAndCall(proxy, impl, ''):");
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(atomWardenProxy), address(atomWardenImplementation), "")
            )
        );

        console2.log("");
        console2.log(
            "STEP 2 - AtomWarden(proxy).reinitialize(claimWindow, minFeeThreshold, signatureThreshold, maxValidAfter, maxValidUntil):"
        );
        console2.log("        Submit from the MultiVault admin EOA/multisig, target=%s", atomWardenProxy);
        console2.logBytes(
            abi.encodeCall(
                AtomWarden.reinitialize,
                (
                    reinitClaimWindow,
                    reinitMinFeeThreshold,
                    reinitSignatureThreshold,
                    reinitMaxValidAfter,
                    reinitMaxValidUntil
                )
            )
        );
    }
}
