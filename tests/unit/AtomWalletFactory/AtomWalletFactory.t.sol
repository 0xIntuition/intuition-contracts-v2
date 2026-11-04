// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { WalletConfig } from "src/interfaces/IMultiVaultCore.sol";

/// @dev forge test --match-path 'tests/unit/AtomWalletFactory/AtomWalletFactory.t.sol'
contract AtomWalletFactoryTest is BaseTest {
    function test_deployAtomWallet_revertsWhen_beaconProxyConstructionFails() external {
        bytes32 atomId =
            createAtomWithDeposit(abi.encodePacked("factory:create2-failure"), getAtomCreationCost(), users.alice);

        // Corrupt the wired entryPoint to address(0): AtomWallet.initialize() reverts on a zero
        // entryPoint, so the BeaconProxy constructor call reverts, and the raw `create2` in
        // `deployAtomWallet` returns address(0) instead of bubbling that revert up.
        (, address atomWarden, address atomWalletBeacon, address atomWalletFactory) = protocol.multiVault.walletConfig();
        resetPrank(users.timelock);
        protocol.multiVault
            .setWalletConfig(
                WalletConfig({
                    entryPoint: address(0),
                    atomWarden: atomWarden,
                    atomWalletBeacon: atomWalletBeacon,
                    atomWalletFactory: atomWalletFactory
                })
            );

        resetPrank(users.alice);
        vm.expectRevert(AtomWalletFactory.AtomWalletFactory_DeployAtomWalletFailed.selector);
        protocol.atomWalletFactory.deployAtomWallet(atomId);
    }
}
