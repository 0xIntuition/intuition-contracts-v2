// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { BondingCurveConfig } from "src/interfaces/IMultiVaultCore.sol";

contract LastUserDustTest is BaseTest {
    function setUp() public override {
        super.setUp();

        BondingCurveConfig memory cfg = protocol.multiVault.getBondingCurveConfig();
        BondingCurveRegistry reg = BondingCurveRegistry(cfg.registry);

        resetPrank(users.admin);
        OffsetProgressiveCurve offsetCurve =
            new OffsetProgressiveCurve("Offset Progressive Bonding Curve", PROGRESSIVE_CURVE_SLOPE, 1e14);
        reg.addBondingCurve(address(offsetCurve));
    }

    function _reserveCurveIds() internal view returns (uint256 linearId, uint256 offsetProgId) {
        return (1, 3);
    }

    function _assertLinearRoundtrip(bytes32 termId, uint256 linearId) internal {
        uint256 aliceLinearShares = protocol.multiVault.getShares(users.alice, termId, linearId);
        (uint256 linAssets, uint256 linShares) = protocol.multiVault.getVault(termId, linearId);
        uint256 linAssetsOut = protocol.multiVault.convertToAssets(termId, linearId, aliceLinearShares);
        address regAddr = protocol.multiVault.getBondingCurveConfig().registry;
        uint256 linSharesFromWithdraw =
            BondingCurveRegistry(regAddr).previewWithdraw(linAssetsOut, linAssets, linShares, linearId);
        uint256 diffLin = aliceLinearShares > linSharesFromWithdraw
            ? aliceLinearShares - linSharesFromWithdraw
            : linSharesFromWithdraw - aliceLinearShares;
        assertLe(diffLin, MIN_SHARES, "linear round-trip should be within MIN_SHARES tolerance");
    }

    function test_previewWithdraw_composition_matches_on_linear_but_not_on_offsetProgressive() public {
        (uint256 linearId, uint256 offsetProgId) = _reserveCurveIds();

        string memory atomStr = "DustAtom";
        bytes32 termId = keccak256(abi.encodePacked(bytes(atomStr)));

        bytes[] memory atomData = new bytes[](1);
        atomData[0] = bytes(atomStr);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        resetPrank(users.alice);
        protocol.multiVault.createAtoms{ value: 1 ether }(atomData, amounts);

        uint256 minShares = 1;
        makeDeposit(users.alice, users.alice, termId, linearId, 2 ether, minShares);
        makeDeposit(users.alice, users.alice, termId, offsetProgId, 2 ether, minShares);

        _assertLinearRoundtrip(termId, linearId);
    }

    function test_last_user_can_redeem_full_balance_on_offset_progressive_after_fix() public {
        (, uint256 offsetProgId) = _reserveCurveIds();

        string memory atomStr = "DustAtomFullRedeem";
        bytes32 termId = keccak256(abi.encodePacked(bytes(atomStr)));

        bytes[] memory atomData = new bytes[](1);
        atomData[0] = bytes(atomStr);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        resetPrank(users.alice);
        protocol.multiVault.createAtoms{ value: 1 ether }(atomData, amounts);

        uint256 minShares = 1;
        makeDeposit(users.alice, users.alice, termId, offsetProgId, 2 ether, minShares);

        uint256 aliceShares = protocol.multiVault.getShares(users.alice, termId, offsetProgId);

        assertGt(aliceShares, 0, "precondition: alice has shares on offset curve");

        (, uint256 assetsPreview) = protocol.multiVault.previewRedeem(termId, offsetProgId, aliceShares);
        assertGt(assetsPreview, 0, "precondition: redeeming should return assets after fees");

        uint256 assetsRedeemed = redeemShares(users.alice, users.alice, termId, offsetProgId, aliceShares, 0);
        assertEq(assetsRedeemed, assetsPreview, "redeemed matches preview (dust-flush covers last-user)");

        uint256 postShares = protocol.multiVault.getShares(users.alice, termId, offsetProgId);
        assertEq(postShares, 0, "user has no leftover shares after full redemption");
    }
}
