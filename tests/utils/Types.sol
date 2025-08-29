// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Trust } from "src/Trust.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { TrustToken } from "src/legacy/TrustToken.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

struct Protocol {
    Trust trust;
    WrappedTrust wrappedTrust;
    TrustToken trustLegacy;
    TrustBonding trustBonding;
    BondingCurveRegistry curveRegistry;
    MultiVault multiVault;
    SatelliteEmissionsController satelliteEmissionsController;
    address payable permit2;
}

struct Users {
    address payable admin;
    address payable controller;
    address payable alice;
    address payable bob;
    address payable charlie;
}
