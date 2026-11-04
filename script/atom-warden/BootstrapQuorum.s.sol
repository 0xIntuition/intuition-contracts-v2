// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";

/*
 * Post-upgrade bootstrap: grants `SIGNER_ROLE` to a second backend signer and
 * raises `signatureThreshold` from 1 to 2. Idempotent — only runs when the
 * threshold is currently 1, so re-executing the script is a no-op once the
 * quorum is in place.
 *
 * MUST run from the AtomWarden DEFAULT_ADMIN_ROLE holder. On mainnet that is
 * the ADMIN_SAFE / governance multisig — in practice this script will be run
 * locally against an Anvil fork (or testnet) by the deployer key, and the
 * production rollout will issue the same two transactions through the
 * multisig UI using the calldata this script logs.
 *
 * INTUITION MAINNET (chain 1155)
 *   ATOM_WARDEN_QUORUM_SECOND_SIGNER=0x... \
 *   forge script script/atom-warden/BootstrapQuorum.s.sol:BootstrapQuorum \
 *     --rpc-url intuition --broadcast --slow --chain 1155
 *
 * INTUITION SEPOLIA (chain 13579)
 *   ATOM_WARDEN_PROXY=0x... \
 *   ATOM_WARDEN_QUORUM_SECOND_SIGNER=0x... \
 *   forge script script/atom-warden/BootstrapQuorum.s.sol:BootstrapQuorum \
 *     --rpc-url intuition_sepolia --broadcast --slow --chain 13579
 */
contract BootstrapQuorum is SetupScript {
    error UnsupportedChain();
    error AtomWardenNotAtThresholdOne();
    error SecondSignerInvalid();

    /// @dev Mainnet AtomWarden proxy — same constant as `UpgradeAtomWardenQuorum`.
    address internal constant ATOM_WARDEN_PROXY_MAINNET = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;

    /// @dev Target threshold after bootstrap. Hardcoded since the demo target is
    ///      explicitly 2-of-N; raising further is a separate operation.
    uint256 internal constant TARGET_THRESHOLD = 2;

    AtomWarden public warden;
    address public secondSigner;

    function setUp() public override {
        super.setUp();

        address proxy;
        if (block.chainid == NETWORK_INTUITION) {
            proxy = ATOM_WARDEN_PROXY_MAINNET;
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA || block.chainid == NETWORK_ANVIL) {
            proxy = vm.envAddress("ATOM_WARDEN_PROXY");
        } else {
            revert UnsupportedChain();
        }

        warden = AtomWarden(payable(proxy));
        secondSigner = vm.envAddress("ATOM_WARDEN_QUORUM_SECOND_SIGNER");
        if (secondSigner == address(0)) revert SecondSignerInvalid();
    }

    function run() public broadcast {
        console2.log("");
        console2.log("BOOTSTRAP QUORUM =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        // Idempotent guard. If threshold is already at the target value the
        // script exits without broadcasting any state-changing call.
        uint256 current = warden.signatureThreshold();
        info("Current signatureThreshold", current);
        if (current == TARGET_THRESHOLD) {
            console2.log("Quorum already bootstrapped - exiting (no-op).");
            return;
        }
        if (current != 1) revert AtomWardenNotAtThresholdOne();

        bytes32 signerRole = warden.SIGNER_ROLE();
        contractInfo("AtomWarden", address(warden));
        contractInfo("Second signer", secondSigner);

        // 1) Grant SIGNER_ROLE - bumps `signerCount` via the role-hook override.
        warden.grantRole(signerRole, secondSigner);

        // 2) Raise threshold. Setter rejects `> signerCount`, so the grant must
        //    succeed first. With a single legacy signer + the new one,
        //    `signerCount` is 2, which exactly admits TARGET_THRESHOLD.
        warden.setSignatureThreshold(TARGET_THRESHOLD);

        info("New signatureThreshold", warden.signatureThreshold());
        info("New signerCount", warden.signerCount());
    }
}
