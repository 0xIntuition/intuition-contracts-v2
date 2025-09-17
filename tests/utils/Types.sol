// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Trust } from "src/Trust.sol";
import { TrustToken } from "src/legacy/TrustToken.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

struct Protocol {
    Trust trust;
    WrappedTrust wrappedTrust;
    TrustToken trustLegacy;
    TrustBonding trustBonding;
    BondingCurveRegistry curveRegistry;
    MultiVault multiVault;
    SatelliteEmissionsController satelliteEmissionsController;
    address payable permit2;
    AtomWalletFactory atomWalletFactory;
    UpgradeableBeacon atomWalletBeacon;
}

struct Users {
    address payable admin;
    address payable controller;
    address payable timelock;
    address payable alice;
    address payable bob;
    address payable charlie;
}
