// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

/*
================================================================================
  v1.1.0 core upgrade — deploy implementations + (optional) fork dry-run
================================================================================

  Single chain-agnostic script that deploys every implementation affected by the
  v1.1.0 upgrade and prints the full timelock / Admin-Safe calldata set, or
  rehearses the whole upgrade against a fork. Live testnet/mainnet execution is
  intentionally deferred (tracked in the V2 Contracts Deployments Notion doc).

  Contracts covered:
    - MultiVault             (TransparentUpgradeableProxy) — linked against MultiVaultLib
    - TrustBonding           (TransparentUpgradeableProxy)
    - AtomWarden             (TransparentUpgradeableProxy)
    - AtomWallet             (UpgradeableBeacon: AtomWalletBeacon)
    - LinearCurve            (TransparentUpgradeableProxy) — REQUIRED, see curve note
    - OffsetProgressiveCurve (TransparentUpgradeableProxy) — REQUIRED, see curve note

  CURVE NOTE (hard sequencing requirement). The upgraded MultiVault calls the
  standardized fee-hook getters (`hasDepositFeeHook` / `hasRedeemFeeHook`) on the
  registry-resolved curve on EVERY deposit and redeem. The live curve proxies run
  implementations that predate those selectors, so if the MultiVault
  implementation is swapped without also swapping every registered curve proxy
  to a recompiled implementation, every deposit and redeem on the chain reverts.
  All curve upgrades therefore ship in the SAME Upgrades-Timelock batch as the
  MultiVault upgrade, and the fork dry-run asserts the registry holds exactly
  the two curves this script covers (a later-registered curve would need its own
  upgrade entry here).

  Supported chains: Intuition Mainnet (1155) and Intuition Testnet (13579) — the
  v1.1.0 core upgrade is Intuition-chain-only, so there are no Base components.

  Governance parameters resolved in setUp() (env-overridable):
    - INTUITION_PARAMETERS_TIMELOCK    -> MultiVault.reinitialize bootstrap
    - ATOM_WARDEN_CLAIM_WINDOW         -> AtomWarden.reinitialize (default 365 days)
    - ATOM_WARDEN_MIN_FEE_THRESHOLD    -> AtomWarden.reinitialize (default 0)
    - ATOM_WARDEN_SIGNATURE_THRESHOLD  -> AtomWarden.reinitialize (default 1, must be > 0)
    - ATOM_WARDEN_MAX_VALID_AFTER      -> AtomWarden.reinitialize (default 1 hours)
    - ATOM_WARDEN_MAX_VALID_UNTIL      -> AtomWarden.reinitialize (default 1 days)
    - ATOM_WARDEN_MAX_CLAIMS_PER_WINDOW-> AtomWarden.reinitialize (default 0 = cap disabled)
    - ATOM_WARDEN_CLAIM_CAP_WINDOW     -> AtomWarden.reinitialize (default 1 days, must be > 0)

  --------------------------------------------------------------------------
  MODE 1 — PRINT (default). Deploys MultiVaultLib (auto-linked by Foundry) and
  the new MultiVault (linked), TrustBonding, AtomWarden, and AtomWallet
  implementations, then prints the upgrade / reinitialize / beacon calldata. No
  proxy or beacon is mutated.

  TESTNET (Intuition Sepolia, chain 13579)
  forge script script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:DeployCoreUpgradeImplementations \
  --optimizer-runs 10000 \
  --rpc-url intuition_sepolia \
  --broadcast \
  --slow \
  --verify \
  --chain 13579 \
  --verifier blockscout \
  --verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

  MAINNET (Intuition, chain 1155)
  forge script script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:DeployCoreUpgradeImplementations \
  --optimizer-runs 10000 \
  --rpc-url intuition \
  --broadcast \
  --slow \
  --verify \
  --chain 1155 \
  --verifier blockscout \
  --verifier-url 'https://intuition.calderaexplorer.xyz/api/'

  --------------------------------------------------------------------------
  MODE 2 — FORK DRY-RUN. Against a fork of the target chain (supplied via the
  CLI `--rpc-url`, NOT an in-script fork), deploys the implementations, applies
  the upgrades via impersonation, and exercises the new surface with inline
  assertions. No broadcast, no live state change.

    FORK_DRY_RUN=true \
    forge script ...:DeployCoreUpgradeImplementations \
      --rpc-url intuition_sepolia -vvv

  For a deterministic pinned-block replay, run against a local anvil fork:

    anvil --fork-url intuition_sepolia --fork-block-number <block>
    FORK_DRY_RUN=true forge script ...:... --rpc-url http://127.0.0.1:8545 -vvv

  The CLI-supplied fork keeps the Foundry-auto-linked MultiVaultLib resident for
  the whole run; selecting a fork inside the script would reset EVM state and
  unlink the library.

  --------------------------------------------------------------------------
  REINITIALIZE NOTE. Both reinitializers are caller-gated to the Admin Safe and
  must run as SEPARATE transactions, never embedded in `upgradeAndCall` — the
  proxy would execute embedded reinit calldata via delegatecall with
  `msg.sender == ProxyAdmin`, which holds neither role and reverts:
    - `MultiVault.reinitialize(address)`           — onlyRole(DEFAULT_ADMIN_ROLE)
    - `AtomWarden.reinitialize(uint256,uint256,uint256,uint48,uint48,uint256,uint256)`
            — gated to `MultiVault.generalConfig().admin`
  So per proxy: (1) Upgrades Timelock -> upgradeAndCall(proxy, impl, "");
  (2) Admin Safe -> <contract>.reinitialize(...). TrustBonding needs no
  reinitializer; AtomWallet is a beacon swap (`upgradeTo`) with no reinitializer.
  After AtomWarden.reinitialize, `signerCount == 0`, so signed claims revert
  until the Admin Safe grants SIGNER_ROLE keys (safe-by-default).
================================================================================
*/
contract DeployCoreUpgradeImplementations is Script {
    /* =================================================== */
    /*                       Errors                        */
    /* =================================================== */
    error UnsupportedChain(uint256 chainId);
    error ZeroParametersTimelock();
    error DryRunAssertionFailed(string reason);

    /* =================================================== */
    /*                   Chain Constants                   */
    /* =================================================== */
    uint256 internal constant NETWORK_INTUITION = 1155;
    uint256 internal constant NETWORK_INTUITION_SEPOLIA = 13_579;

    /// @dev EIP-1967 implementation slot: keccak256("eip1967.proxy.implementation") - 1
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev AtomWarden reinitialize defaults. Mirror IntuitionDeployAndSetup /
    ///      UpgradeAtomWardenQuorum so the upgrade lands at a known-good
    ///      baseline; admin rotates via the regular setters after reinitialize.
    uint256 internal constant DEFAULT_CLAIM_WINDOW = 365 days;
    uint256 internal constant DEFAULT_MIN_FEE_THRESHOLD = 0;
    uint256 internal constant DEFAULT_SIGNATURE_THRESHOLD = 1;
    uint48 internal constant DEFAULT_MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant DEFAULT_MAX_VALID_UNTIL = uint48(1 days);
    /// @dev 0 = authorized-claim cap disabled; arm deliberately via env or the admin setter.
    uint256 internal constant DEFAULT_MAX_CLAIMS_PER_WINDOW = 0;
    uint256 internal constant DEFAULT_CLAIM_CAP_WINDOW = 1 days;

    /// @dev Per-chain proxy / governance address book. Sourced from
    ///      contracts/core/README.md (deployed-contracts tables) and the
    ///      v1.1.0 upgrade scope doc.
    struct Addresses {
        address multiVaultProxy;
        address multiVaultProxyAdmin;
        address trustBondingProxy;
        address trustBondingProxyAdmin;
        address atomWardenProxy;
        address atomWardenProxyAdmin;
        address atomWalletBeacon;
        address bondingCurveRegistryProxy;
        address linearCurveProxy;
        address linearCurveProxyAdmin;
        address offsetProgressiveCurveProxy;
        address offsetProgressiveCurveProxyAdmin;
        address upgradesTimelock;
        address parametersTimelock;
    }

    /* =================================================== */
    /*                  Resolved Config                    */
    /* =================================================== */
    /// @dev Per-chain proxy / governance addresses, resolved in {setUp}.
    Addresses internal addr;
    /// @dev Parameters TimelockController bootstrapped into MultiVault.timelock.
    address public parametersTimelock;

    /// @dev AtomWarden.reinitialize parameters, resolved in {setUp}.
    uint256 internal reinitClaimWindow;
    uint256 internal reinitMinFeeThreshold;
    uint256 internal reinitSignatureThreshold;
    uint48 internal reinitMaxValidAfter;
    uint48 internal reinitMaxValidUntil;
    uint256 internal reinitMaxClaimsPerWindow;
    uint256 internal reinitClaimCapWindow;

    /* =================================================== */
    /*                  Deploy Artifacts                   */
    /* =================================================== */
    MultiVault public multiVaultImplementation;
    TrustBonding public trustBondingImplementation;
    AtomWarden public atomWardenImplementation;
    AtomWallet public atomWalletImplementation;
    LinearCurve public linearCurveImplementation;
    OffsetProgressiveCurve public offsetProgressiveCurveImplementation;

    /* =================================================== */
    /*                    Entry Points                     */
    /* =================================================== */

    /// @notice Resolves the per-chain address book and the governance parameters
    ///         to bootstrap. The parameters-timelock defaults to the resolved
    ///         chain's Parameters TimelockController; AtomWarden reinit params
    ///         default to the known-good baseline. All are env-overridable for a
    ///         rotated config or a one-off run. Reverts on any non-Intuition
    ///         chain — the v1.1.0 core upgrade is Intuition-chain-only.
    function setUp() public {
        addr = _addresses(block.chainid);

        parametersTimelock = vm.envOr("INTUITION_PARAMETERS_TIMELOCK", addr.parametersTimelock);
        if (parametersTimelock == address(0)) revert ZeroParametersTimelock();

        reinitClaimWindow = vm.envOr("ATOM_WARDEN_CLAIM_WINDOW", DEFAULT_CLAIM_WINDOW);
        reinitMinFeeThreshold = vm.envOr("ATOM_WARDEN_MIN_FEE_THRESHOLD", DEFAULT_MIN_FEE_THRESHOLD);
        reinitSignatureThreshold = vm.envOr("ATOM_WARDEN_SIGNATURE_THRESHOLD", DEFAULT_SIGNATURE_THRESHOLD);
        // forge-lint: disable-next-line(unsafe-typecast)
        reinitMaxValidAfter = uint48(vm.envOr("ATOM_WARDEN_MAX_VALID_AFTER", uint256(DEFAULT_MAX_VALID_AFTER)));
        // forge-lint: disable-next-line(unsafe-typecast)
        reinitMaxValidUntil = uint48(vm.envOr("ATOM_WARDEN_MAX_VALID_UNTIL", uint256(DEFAULT_MAX_VALID_UNTIL)));
        reinitMaxClaimsPerWindow = vm.envOr("ATOM_WARDEN_MAX_CLAIMS_PER_WINDOW", DEFAULT_MAX_CLAIMS_PER_WINDOW);
        reinitClaimCapWindow = vm.envOr("ATOM_WARDEN_CLAIM_CAP_WINDOW", DEFAULT_CLAIM_CAP_WINDOW);
    }

    /// @notice Default entry point. Print mode unless `FORK_DRY_RUN=true`.
    function run() external {
        if (vm.envOr("FORK_DRY_RUN", false)) {
            _forkDryRun();
        } else {
            _printMode();
        }
    }

    /* =================================================== */
    /*                  Mode 1 — Print                     */
    /* =================================================== */

    function _printMode() internal {
        console2.log("");
        console2.log("DEPLOYMENTS (print mode): =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("ChainID:", block.chainid);

        vm.startBroadcast();
        _deployImplementations();
        vm.stopBroadcast();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("MultiVault Implementation             :", address(multiVaultImplementation));
        console2.log("TrustBonding Implementation           :", address(trustBondingImplementation));
        console2.log("AtomWarden Implementation             :", address(atomWardenImplementation));
        console2.log("AtomWallet Implementation             :", address(atomWalletImplementation));
        console2.log("LinearCurve Implementation            :", address(linearCurveImplementation));
        console2.log("OffsetProgressiveCurve Implementation :", address(offsetProgressiveCurveImplementation));
        console2.log("");
        console2.log("MultiVaultLib is auto-deployed and linked by Foundry as the first broadcast tx;");
        console2.log("its address is recorded in broadcast/.../run-latest.json and in the --verify output.");

        _logUpgradeCalldata();
    }

    /// @dev Prints the calldata set for the release, grouped by signer. The
    ///      Upgrades Timelock batch is all empty-data upgrades; the Admin Safe
    ///      batch carries the two caller-gated reinitializers (see header note).
    ///      Round-trippable and free of secrets (all addresses are public).
    function _logUpgradeCalldata() internal view {
        console2.log("");
        console2.log("UPGRADES TIMELOCK BATCH (empty calldata): =+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        console2.log("");
        console2.log("[1] MultiVault upgrade (-> ProxyAdmin %s)", addr.multiVaultProxyAdmin);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(addr.multiVaultProxy), address(multiVaultImplementation), "")
            )
        );

        console2.log("");
        console2.log("[2] TrustBonding upgrade (-> ProxyAdmin %s)", addr.trustBondingProxyAdmin);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(addr.trustBondingProxy), address(trustBondingImplementation), "")
            )
        );

        console2.log("");
        console2.log("[3] AtomWarden upgrade (-> ProxyAdmin %s)", addr.atomWardenProxyAdmin);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(addr.atomWardenProxy), address(atomWardenImplementation), "")
            )
        );

        console2.log("");
        console2.log("[4] AtomWallet beacon upgrade (-> AtomWalletBeacon %s)", addr.atomWalletBeacon);
        console2.logBytes(abi.encodeCall(UpgradeableBeacon.upgradeTo, (address(atomWalletImplementation))));

        console2.log("");
        console2.log(
            "[5] LinearCurve upgrade (-> ProxyAdmin %s) [REQUIRED with [1], see curve note]", addr.linearCurveProxyAdmin
        );
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(addr.linearCurveProxy), address(linearCurveImplementation), "")
            )
        );

        console2.log("");
        console2.log(
            "[6] OffsetProgressiveCurve upgrade (-> ProxyAdmin %s) [REQUIRED with [1], see curve note]",
            addr.offsetProgressiveCurveProxyAdmin
        );
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (
                    ITransparentUpgradeableProxy(addr.offsetProgressiveCurveProxy),
                    address(offsetProgressiveCurveImplementation),
                    ""
                )
            )
        );

        console2.log("");
        console2.log("ADMIN SAFE BATCH (separate txs, caller-gated): =+=+=+=+=+=+=+=+=+=+=+=+");

        console2.log("");
        console2.log(
            "[7] MultiVault.reinitialize(parametersTimelock = %s) -> proxy %s", parametersTimelock, addr.multiVaultProxy
        );
        console2.logBytes(abi.encodeCall(MultiVault.reinitialize, (parametersTimelock)));

        console2.log("");
        console2.log("[8] AtomWarden.reinitialize(...) -> proxy %s", addr.atomWardenProxy);
        console2.log("    claimWindow=%s minFeeThreshold=%s", reinitClaimWindow, reinitMinFeeThreshold);
        console2.log(
            "    signatureThreshold=%s maxValidAfter=%s maxValidUntil=%s",
            reinitSignatureThreshold,
            uint256(reinitMaxValidAfter),
            uint256(reinitMaxValidUntil)
        );
        console2.log(
            "    maxClaimsPerWindow=%s (0 = cap disabled) claimCapWindow=%s",
            reinitMaxClaimsPerWindow,
            reinitClaimCapWindow
        );
        console2.logBytes(
            abi.encodeCall(
                AtomWarden.reinitialize,
                (
                    reinitClaimWindow,
                    reinitMinFeeThreshold,
                    reinitSignatureThreshold,
                    reinitMaxValidAfter,
                    reinitMaxValidUntil,
                    reinitMaxClaimsPerWindow,
                    reinitClaimCapWindow
                )
            )
        );

        console2.log("");
        console2.log("FOLLOW-UP (operational, post-deployment, by the Admin Safe holding DEFAULT_ADMIN_ROLE):");
        console2.log(" - AtomWarden: grant SIGNER_ROLE to each backend signer key (and OPERATOR_ROLE as");
        console2.log("   needed) before signed claims can succeed.");
        console2.log(" - MultiVault PAUSER_ROLE: already granted to generalConfig.admin by reinitialize, but");
        console2.log("   optionally also grant it to a separate lower-threshold pauser Safe (e.g. 1-of-N or");
        console2.log("   2-of-N) for faster incident response -- grantRole(PAUSER_ROLE, pauserSafe).");
    }

    /* =================================================== */
    /*               Mode 2 — Fork Dry-Run                 */
    /* =================================================== */

    function _forkDryRun() internal {
        // The fork is supplied by the CLI (`--rpc-url` / local anvil fork), so
        // block.chainid already reflects the target chain (resolved in setUp)
        // and the Foundry-auto-linked MultiVaultLib stays resident for the whole
        // run.
        console2.log("");
        console2.log("FORK DRY-RUN: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("ChainID:", block.chainid);

        MultiVault multiVault = MultiVault(addr.multiVaultProxy);
        AtomWarden atomWarden = AtomWarden(addr.atomWardenProxy);

        // Read the live DEFAULT_ADMIN_ROLE holder (the Admin Safe) from config.
        // It also gates AtomWarden.reinitialize (msg.sender == generalConfig.admin).
        (address adminSafe,,,,,,,) = multiVault.generalConfig();

        // 1. Deploy implementations on the fork (Foundry auto-links MultiVaultLib).
        _deployImplementations();

        // 2. Upgrades-Timelock batch — bare upgrades (empty calldata) + beacon swap.
        vm.startPrank(addr.upgradesTimelock);
        ProxyAdmin(addr.multiVaultProxyAdmin)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(addr.multiVaultProxy)), address(multiVaultImplementation), ""
            );
        ProxyAdmin(addr.trustBondingProxyAdmin)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(addr.trustBondingProxy)), address(trustBondingImplementation), ""
            );
        ProxyAdmin(addr.atomWardenProxyAdmin)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(addr.atomWardenProxy)), address(atomWardenImplementation), ""
            );
        UpgradeableBeacon(addr.atomWalletBeacon).upgradeTo(address(atomWalletImplementation));
        // Curve upgrades MUST land in the same batch as the MultiVault upgrade: the new MultiVault
        // calls the fee-hook getters on the registry-resolved curve on every deposit/redeem, and the
        // old curve implementations lack those selectors (see the curve note in the header).
        ProxyAdmin(addr.linearCurveProxyAdmin)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(addr.linearCurveProxy)), address(linearCurveImplementation), ""
            );
        ProxyAdmin(addr.offsetProgressiveCurveProxyAdmin)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(addr.offsetProgressiveCurveProxy)),
                address(offsetProgressiveCurveImplementation),
                ""
            );
        vm.stopPrank();

        // 3. Admin-Safe batch — the two caller-gated reinitializers (separate txs).
        vm.startPrank(adminSafe);
        multiVault.reinitialize(parametersTimelock);
        atomWarden.reinitialize(
            reinitClaimWindow,
            reinitMinFeeThreshold,
            reinitSignatureThreshold,
            reinitMaxValidAfter,
            reinitMaxValidUntil,
            reinitMaxClaimsPerWindow,
            reinitClaimCapWindow
        );
        vm.stopPrank();

        // 4. Post-upgrade assertions.
        _assertUpgradeApplied(multiVault, adminSafe);
        _assertAtomWardenApplied(atomWarden, adminSafe);
        _assertAtomWalletApplied();
        _assertCurvesApplied();

        // 5. Exercise the new MultiVault multicall surface.
        _exerciseMulticall(multiVault);
        _exerciseMulticallPayable(multiVault);

        console2.log("");
        console2.log("FORK DRY-RUN PASSED: all assertions + multicall exercises succeeded.");
    }

    function _assertUpgradeApplied(MultiVault multiVault, address adminSafe) internal view {
        // Implementation pointers updated (EIP-1967 slots).
        if (_implementationOf(addr.multiVaultProxy) != address(multiVaultImplementation)) {
            revert DryRunAssertionFailed("MultiVault impl pointer");
        }
        if (_implementationOf(addr.trustBondingProxy) != address(trustBondingImplementation)) {
            revert DryRunAssertionFailed("TrustBonding impl pointer");
        }

        // timelock slot bootstrapped to the parameters-timelock.
        if (multiVault.timelock() != parametersTimelock) revert DryRunAssertionFailed("timelock slot");

        // PAUSER_ROLE granted to generalConfig.admin.
        if (!multiVault.hasRole(multiVault.PAUSER_ROLE(), adminSafe)) {
            revert DryRunAssertionFailed("PAUSER_ROLE grant");
        }

        console2.log("  [ok] MultiVault + TrustBonding impl pointers updated");
        console2.log("  [ok] timelock slot == parameters-timelock");
        console2.log("  [ok] PAUSER_ROLE granted to generalConfig.admin");
    }

    /// @dev AtomWarden: impl pointer + reinitialize bootstrap. Granting a sample
    ///      SIGNER_ROLE (as the Admin Safe) proves the overridden _grantRole
    ///      signer-counting path is live; signerCount starts at 0 post-reinit.
    function _assertAtomWardenApplied(AtomWarden atomWarden, address adminSafe) internal {
        if (_implementationOf(addr.atomWardenProxy) != address(atomWardenImplementation)) {
            revert DryRunAssertionFailed("AtomWarden impl pointer");
        }
        if (atomWarden.signatureThreshold() != reinitSignatureThreshold || reinitSignatureThreshold == 0) {
            revert DryRunAssertionFailed("AtomWarden signatureThreshold");
        }
        if (!atomWarden.hasRole(atomWarden.DEFAULT_ADMIN_ROLE(), adminSafe)) {
            revert DryRunAssertionFailed("AtomWarden admin role");
        }
        if (atomWarden.signerCount() != 0) revert DryRunAssertionFailed("AtomWarden signerCount seed");
        if (atomWarden.maxClaimsPerWindow() != reinitMaxClaimsPerWindow) {
            revert DryRunAssertionFailed("AtomWarden maxClaimsPerWindow");
        }
        if (atomWarden.claimCapWindow() != reinitClaimCapWindow || reinitClaimCapWindow == 0) {
            revert DryRunAssertionFailed("AtomWarden claimCapWindow");
        }

        // Precompute the role id outside the prank: `vm.prank` arms only the next
        // CALL, and `SIGNER_ROLE()` would otherwise consume it before `grantRole`.
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        address sampleSigner = makeAddr("dryRunSigner");
        vm.prank(adminSafe);
        atomWarden.grantRole(signerRole, sampleSigner);
        if (atomWarden.signerCount() != 1) revert DryRunAssertionFailed("AtomWarden signerCount after grant");

        console2.log("  [ok] AtomWarden impl pointer updated + reinitialized (signatureThreshold set)");
        console2.log("  [ok] AtomWarden SIGNER_ROLE grant advances signerCount");
    }

    /// @dev AtomWallet beacon pointer updated. The end-to-end claim path
    ///      (AtomWarden -> AtomWallet.completeClaim -> owner execute) is covered
    ///      by the upgrade regression suite; here we confirm the beacon swap so
    ///      every BeaconProxy wallet resolves to the new implementation.
    function _assertAtomWalletApplied() internal view {
        if (UpgradeableBeacon(addr.atomWalletBeacon).implementation() != address(atomWalletImplementation)) {
            revert DryRunAssertionFailed("AtomWallet beacon implementation");
        }
        console2.log("  [ok] AtomWallet beacon implementation updated");
    }

    /// @dev Curve proxies: impl pointers updated, the fee-hook getters resolve (proving the new
    ///      MultiVault's per-deposit hook probe cannot revert on a missing selector), and the
    ///      registry holds exactly the curves this script upgrades — a curve registered after this
    ///      script was written would be missed and would brick its own vaults' deposits.
    function _assertCurvesApplied() internal view {
        if (_implementationOf(addr.linearCurveProxy) != address(linearCurveImplementation)) {
            revert DryRunAssertionFailed("LinearCurve impl pointer");
        }
        if (_implementationOf(addr.offsetProgressiveCurveProxy) != address(offsetProgressiveCurveImplementation)) {
            revert DryRunAssertionFailed("OffsetProgressiveCurve impl pointer");
        }

        BondingCurveRegistry registry = BondingCurveRegistry(addr.bondingCurveRegistryProxy);
        if (registry.count() != 2) revert DryRunAssertionFailed("registry.count != covered curves");
        if (registry.curveAddresses(1) != addr.linearCurveProxy) {
            revert DryRunAssertionFailed("registry curve id 1 != LinearCurve");
        }
        if (registry.curveAddresses(2) != addr.offsetProgressiveCurveProxy) {
            revert DryRunAssertionFailed("registry curve id 2 != OffsetProgressiveCurve");
        }

        if (
            IBaseCurve(addr.linearCurveProxy).hasDepositFeeHook()
                || IBaseCurve(addr.linearCurveProxy).hasRedeemFeeHook()
        ) {
            revert DryRunAssertionFailed("LinearCurve hook getters must be false");
        }
        if (
            IBaseCurve(addr.offsetProgressiveCurveProxy).hasDepositFeeHook()
                || IBaseCurve(addr.offsetProgressiveCurveProxy).hasRedeemFeeHook()
        ) {
            revert DryRunAssertionFailed("OffsetProgressiveCurve hook getters must be false");
        }

        console2.log("  [ok] LinearCurve + OffsetProgressiveCurve impl pointers updated");
        console2.log("  [ok] registry covers exactly the upgraded curves; hook getters resolve (false)");
    }

    /// @dev Canonical non-payable multicall: two read sub-calls. Confirms the
    ///      selector resolves and the anti-nesting guard executes cleanly.
    function _exerciseMulticall(MultiVault multiVault) internal {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("currentEpoch()");
        calls[1] = abi.encodeWithSignature("getAtomCost()");
        multiVault.multicall(calls);
        console2.log("  [ok] multicall(bytes[]) resolved");
    }

    /// @dev Flagship multicallPayable: createAtoms + deposit into the same atom
    ///      in one tx. The atom id is predicted via the pure `calculateAtomId`,
    ///      so the deposit sub-call can target it.
    function _exerciseMulticallPayable(MultiVault multiVault) internal {
        bytes memory atomData = bytes("v1.1.0-dryrun-flagship-atom");
        bytes32 atomId = multiVault.calculateAtomId(atomData);
        uint256 defaultCurveId = multiVault.getBondingCurveConfig().defaultCurveId;

        uint256 atomCost = multiVault.getAtomCost();
        (,,,, uint256 minDeposit,,,) = multiVault.generalConfig();

        address depositor = makeAddr("dryRunDepositor");
        vm.deal(depositor, atomCost + minDeposit);

        bytes[] memory atomDatas = new bytes[](1);
        atomDatas[0] = atomData;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = atomCost;

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(IMultiVault.createAtoms, (atomDatas, createAssets));
        calls[1] = abi.encodeCall(IMultiVault.deposit, (depositor, atomId, defaultCurveId, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = atomCost;
        values[1] = minDeposit;

        vm.prank(depositor);
        multiVault.multicallPayable{ value: atomCost + minDeposit }(calls, values);

        if (multiVault.getAtomCreator(atomId) != depositor) {
            revert DryRunAssertionFailed("multicallPayable atom creator");
        }
        console2.log("  [ok] multicallPayable(createAtoms + deposit) resolved");
    }

    /* =================================================== */
    /*                  Shared Helpers                     */
    /* =================================================== */

    function _deployImplementations() internal {
        multiVaultImplementation = new MultiVault();
        console2.log("MultiVault Implementation deployed:", address(multiVaultImplementation));

        trustBondingImplementation = new TrustBonding();
        console2.log("TrustBonding Implementation deployed:", address(trustBondingImplementation));

        atomWardenImplementation = new AtomWarden();
        console2.log("AtomWarden Implementation deployed:", address(atomWardenImplementation));

        atomWalletImplementation = new AtomWallet();
        console2.log("AtomWallet Implementation deployed:", address(atomWalletImplementation));

        linearCurveImplementation = new LinearCurve();
        console2.log("LinearCurve Implementation deployed:", address(linearCurveImplementation));

        offsetProgressiveCurveImplementation = new OffsetProgressiveCurve();
        console2.log("OffsetProgressiveCurve Implementation deployed:", address(offsetProgressiveCurveImplementation));
    }

    function _implementationOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    function _addresses(uint256 chainId) internal pure returns (Addresses memory) {
        if (chainId == NETWORK_INTUITION) {
            // Intuition Mainnet (chain 1155).
            return Addresses({
                multiVaultProxy: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e,
                multiVaultProxyAdmin: 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8,
                trustBondingProxy: 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617,
                trustBondingProxyAdmin: 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62,
                atomWardenProxy: 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165,
                atomWardenProxyAdmin: 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A,
                atomWalletBeacon: 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF,
                bondingCurveRegistryProxy: 0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930,
                linearCurveProxy: 0xc3eFD5471dc63d74639725f381f9686e3F264366,
                linearCurveProxyAdmin: 0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c,
                offsetProgressiveCurveProxy: 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d,
                offsetProgressiveCurveProxyAdmin: 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7,
                upgradesTimelock: 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1,
                parametersTimelock: 0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA
            });
        }

        if (chainId == NETWORK_INTUITION_SEPOLIA) {
            // Intuition Testnet (chain 13579).
            return Addresses({
                multiVaultProxy: 0xeBc49d356B7f64D888130D85CC6D17114a6843ec,
                multiVaultProxyAdmin: 0x06996b285C0763fD0459dB31e8FAF2D8d498c1a8,
                trustBondingProxy: 0xfa1bF01055239C674845aAEe5A5416f98f801BE3,
                trustBondingProxyAdmin: 0xaC09e8a5A3e6E5AA1A8ee2238136a2eA4F9B2304,
                atomWardenProxy: 0x1f2622D57D09B5E21738a8e0acE24ed9d4a2E32F,
                atomWardenProxyAdmin: 0x5FA28AA0E9fc58cEBE3E1Fe4F2264F32111888fb,
                atomWalletBeacon: 0x8497Eb80fB9742265AeFE711856b2ecACABF1Cb0,
                bondingCurveRegistryProxy: 0xbFE8068d5C5117c57d37464e33c937bC08317F88,
                linearCurveProxy: 0x9f272DAEfa66e031081430Ec138FD34190d6f671,
                linearCurveProxyAdmin: 0x99b42bF374644F82bE85cd5c74D28f8269409f19,
                offsetProgressiveCurveProxy: 0xd50CB061b1CE0560108fc3D58685d4eDb7594f20,
                offsetProgressiveCurveProxyAdmin: 0x4EB7e35C74A532E90095c8792268321875E671F9,
                upgradesTimelock: 0x81c66D5dD09F1dEF8493E5A5B459e2E9028a4430,
                parametersTimelock: 0xA87E4EEd6C71966E938b45c0e2127344DC597D12
            });
        }

        revert UnsupportedChain(chainId);
    }
}
