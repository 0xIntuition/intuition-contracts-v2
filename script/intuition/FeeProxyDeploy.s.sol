// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { FeeProxy } from "src/periphery/FeeProxy.sol";

/*
LOCAL
forge script script/intuition/FeeProxyDeploy.s.sol:FeeProxyDeploy \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast

TESTNET (Intuition Sepolia, chain 13579)
forge script script/intuition/FeeProxyDeploy.s.sol:FeeProxyDeploy \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

MAINNET (Intuition, chain 1155)
forge script script/intuition/FeeProxyDeploy.s.sol:FeeProxyDeploy \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

/// @title FeeProxyDeploy
/// @notice Deploys a fresh `FeeProxy` implementation behind a
///         `TransparentUpgradeableProxy`, atomically initialized with the
///         per-environment configuration. Reads every chain-specific value
///         from the environment so the script stays free of hard-coded
///         addresses and can be re-run on any network without diffs.
/// @dev    Required env vars (per supported chain):
///           - `<NETWORK>_FEE_PROXY_MULTI_VAULT`        — address of the
///             {MultiVault} proxy this {FeeProxy} forwards to.
///           - `<NETWORK>_FEE_PROXY_TREASURY`           — registration-fee
///             treasury (TRUST recipient).
///           - `<NETWORK>_FEE_PROXY_ADMIN`              — admin (granted
///             `DEFAULT_ADMIN_ROLE` and `PAUSER_ROLE` at init time; rotates
///             other role members, tunes protocol caps, and is the only
///             role that can `unpause` the contract or `unpauseAffiliate`).
///           - `<NETWORK>_FEE_PROXY_PROXY_ADMIN_OWNER`  — TUP proxy admin
///             (typically the protocol's upgrades timelock).
///         Optional env vars (per chain; sensible defaults supplied):
///           - `<NETWORK>_FEE_PROXY_MAX_FEE_BPS`        — initial bps cap.
///           - `<NETWORK>_FEE_PROXY_MAX_FIXED_FEE`      — initial fixed-fee
///             cap, in TRUST wei.
///           - `<NETWORK>_FEE_PROXY_REGISTRATION_FEE`   — initial registration
///             fee, in TRUST wei.
///         `<NETWORK>` ∈ `{ANVIL, INTUITION_SEPOLIA, INTUITION}`.
contract FeeProxyDeploy is SetupScript {
    /* =================================================== */
    /*                       DEFAULTS                      */
    /* =================================================== */

    /// @dev Default protocol-level caps applied if the per-network env var is
    ///      unset. Chosen as conservative starting points; admin can re-tune
    ///      post-deploy via `setMaxFeeBps` / `setMaxFixedFee` / `setRegistrationFee`.
    uint256 public constant DEFAULT_MAX_FEE_BPS = 1000; // 10%
    uint256 public constant DEFAULT_MAX_FIXED_FEE = 1 ether; // 1 TRUST
    uint256 public constant DEFAULT_REGISTRATION_FEE = 10 ether; // 10 TRUST

    /* =================================================== */
    /*                      DEPLOYED                       */
    /* =================================================== */

    FeeProxy public feeProxyImplementation;
    TransparentUpgradeableProxy public feeProxyProxyContract;
    FeeProxy public feeProxyContract;

    /* =================================================== */
    /*                   RESOLVED CONFIG                   */
    /* =================================================== */

    address internal FEE_PROXY_MULTI_VAULT;
    address internal FEE_PROXY_TREASURY;
    address internal FEE_PROXY_ADMIN;
    address internal FEE_PROXY_PROXY_ADMIN_OWNER;
    uint256 internal FEE_PROXY_MAX_FEE_BPS;
    uint256 internal FEE_PROXY_MAX_FIXED_FEE;
    uint256 internal FEE_PROXY_REGISTRATION_FEE;

    function setUp() public override {
        super.setUp();
        _resolveFeeProxyConfig();

        console2.log("");
        console2.log("FEE PROXY CONFIG: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=");
        info("FEE_PROXY_MULTI_VAULT", FEE_PROXY_MULTI_VAULT);
        info("FEE_PROXY_TREASURY", FEE_PROXY_TREASURY);
        info("FEE_PROXY_ADMIN", FEE_PROXY_ADMIN);
        info("FEE_PROXY_PROXY_ADMIN_OWNER", FEE_PROXY_PROXY_ADMIN_OWNER);
        info("FEE_PROXY_MAX_FEE_BPS", FEE_PROXY_MAX_FEE_BPS);
        info("FEE_PROXY_MAX_FIXED_FEE", FEE_PROXY_MAX_FIXED_FEE);
        info("FEE_PROXY_REGISTRATION_FEE", FEE_PROXY_REGISTRATION_FEE);
    }

    function run() public broadcast {
        feeProxyImplementation = new FeeProxy();
        console2.log("");
        console2.log("FeeProxy implementation deployed at:", address(feeProxyImplementation));

        bytes memory initData = abi.encodeWithSelector(
            FeeProxy.initialize.selector,
            FEE_PROXY_MULTI_VAULT,
            FEE_PROXY_TREASURY,
            FEE_PROXY_ADMIN,
            FEE_PROXY_MAX_FEE_BPS,
            FEE_PROXY_MAX_FIXED_FEE,
            FEE_PROXY_REGISTRATION_FEE
        );

        feeProxyProxyContract =
            new TransparentUpgradeableProxy(address(feeProxyImplementation), FEE_PROXY_PROXY_ADMIN_OWNER, initData);
        feeProxyContract = FeeProxy(payable(address(feeProxyProxyContract)));
        console2.log("FeeProxy proxy deployed at:", address(feeProxyProxyContract));

        // Sanity-check the on-chain state matches the requested config.
        require(feeProxyContract.multiVault() == FEE_PROXY_MULTI_VAULT, "multiVault mismatch");
        require(feeProxyContract.treasury() == FEE_PROXY_TREASURY, "treasury mismatch");
        require(feeProxyContract.hasRole(feeProxyContract.DEFAULT_ADMIN_ROLE(), FEE_PROXY_ADMIN), "admin mismatch");
        require(feeProxyContract.hasRole(feeProxyContract.PAUSER_ROLE(), FEE_PROXY_ADMIN), "pauser mismatch");
        require(feeProxyContract.maxFeeBps() == FEE_PROXY_MAX_FEE_BPS, "maxFeeBps mismatch");
        require(feeProxyContract.maxFixedFee() == FEE_PROXY_MAX_FIXED_FEE, "maxFixedFee mismatch");
        require(feeProxyContract.registrationFee() == FEE_PROXY_REGISTRATION_FEE, "registrationFee mismatch");
        require(!feeProxyContract.paused(), "deployed paused");

        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("FeeProxy implementation", address(feeProxyImplementation));
        contractInfo("FeeProxy proxy", address(feeProxyProxyContract));
    }

    function _resolveFeeProxyConfig() internal {
        string memory prefix;
        if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            prefix = "INTUITION_SEPOLIA";
        } else if (block.chainid == NETWORK_INTUITION) {
            prefix = "INTUITION";
        } else if (block.chainid == NETWORK_ANVIL) {
            prefix = "ANVIL";
        } else {
            revert("FeeProxyDeploy: unsupported chain");
        }

        FEE_PROXY_MULTI_VAULT = vm.envAddress(string.concat(prefix, "_FEE_PROXY_MULTI_VAULT"));
        FEE_PROXY_TREASURY = vm.envAddress(string.concat(prefix, "_FEE_PROXY_TREASURY"));
        FEE_PROXY_ADMIN = vm.envAddress(string.concat(prefix, "_FEE_PROXY_ADMIN"));
        FEE_PROXY_PROXY_ADMIN_OWNER = vm.envAddress(string.concat(prefix, "_FEE_PROXY_PROXY_ADMIN_OWNER"));

        FEE_PROXY_MAX_FEE_BPS = vm.envOr(string.concat(prefix, "_FEE_PROXY_MAX_FEE_BPS"), DEFAULT_MAX_FEE_BPS);
        FEE_PROXY_MAX_FIXED_FEE = vm.envOr(string.concat(prefix, "_FEE_PROXY_MAX_FIXED_FEE"), DEFAULT_MAX_FIXED_FEE);
        FEE_PROXY_REGISTRATION_FEE =
            vm.envOr(string.concat(prefix, "_FEE_PROXY_REGISTRATION_FEE"), DEFAULT_REGISTRATION_FEE);
    }
}
