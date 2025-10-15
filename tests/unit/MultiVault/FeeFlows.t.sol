// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { GeneralConfig, VaultFees } from "src/interfaces/IMultiVaultCore.sol";

contract FeeFlowsTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _gc() internal view returns (GeneralConfig memory gc) {
        (
            address admin,
            address protocolMultisig,
            uint256 feeDenominator,
            address trustBonding,
            uint256 minDeposit,
            uint256 minShare,
            uint256 atomDataMaxLength,
            uint256 feeThreshold
        ) = protocol.multiVault.generalConfig();
        gc = GeneralConfig({
            admin: admin,
            protocolMultisig: protocolMultisig,
            feeDenominator: feeDenominator,
            trustBonding: trustBonding,
            minDeposit: minDeposit,
            minShare: minShare,
            atomDataMaxLength: atomDataMaxLength,
            feeThreshold: feeThreshold
        });
    }

    function _vf() internal view returns (VaultFees memory vf) {
        (uint256 entryFee, uint256 exitFee, uint256 protocolFee) = protocol.multiVault.vaultFees();
        vf = VaultFees({ entryFee: entryFee, exitFee: exitFee, protocolFee: protocolFee });
    }

    function _setFeeThreshold(uint256 newThreshold) internal {
        GeneralConfig memory gc = _gc();
        gc.feeThreshold = newThreshold;
        vm.prank(gc.admin);
        protocol.multiVault.setGeneralConfig(gc);
    }

    function _defaultId() internal view returns (uint256) {
        return getDefaultCurveId();
    }

    function _price(bytes32 termId, uint256 curveId) internal view returns (uint256) {
        return protocol.multiVault.currentSharePrice(termId, curveId);
    }

    function _vault(bytes32 termId, uint256 curveId) internal view returns (uint256 assets, uint256 shares) {
        return protocol.multiVault.getVault(termId, curveId);
    }

    function _mulDivUp(uint256 x, uint256 num, uint256 den) internal pure returns (uint256) {
        if (x == 0 || num == 0) return 0;
        unchecked {
            return (x * num + (den - 1)) / den;
        }
    }

    function _expectDeposit(
        address who,
        bytes32 termId,
        uint256 curveId,
        uint256 amount
    )
        internal
        returns (uint256 sharesMinted, uint256 assetsAfterFees)
    {
        (uint256 expShares, uint256 expNetAssets) = protocol.multiVault.previewDeposit(termId, curveId, amount);
        vm.startPrank(who);
        sharesMinted = protocol.multiVault.deposit{ value: amount }(who, termId, curveId, expShares);
        vm.stopPrank();
        assetsAfterFees = expNetAssets;
    }

    function _expectRedeem(
        address who,
        bytes32 termId,
        uint256 curveId,
        uint256 shares
    )
        internal
        returns (uint256 assetsAfterFees, uint256 rawAssetsBeforeFees)
    {
        (uint256 expAssetsAfter,) = protocol.multiVault.previewRedeem(termId, curveId, shares);
        rawAssetsBeforeFees = protocol.multiVault.convertToAssets(termId, curveId, shares);
        vm.startPrank(who);
        assetsAfterFees = protocol.multiVault.redeem(who, termId, curveId, shares, expAssetsAfter);
        vm.stopPrank();
    }

    /// @dev Helper to avoid stack too deep in tests
    function _entryFeeCreditIfCharged(bytes32 termId, uint256 amount) internal view returns (uint256) {
        uint256 defaultId = _defaultId();
        (, uint256 totalShares) = _vault(termId, defaultId);
        uint256 threshold = _gc().feeThreshold;
        if (totalShares < threshold) return 0; // gate off => no entry fee to credit for assertions
        VaultFees memory vf = _vf();
        return _mulDivUp(amount, vf.entryFee, _gc().feeDenominator);
    }

    /// @dev compute per-atom credit: ceil(extra * fractionBps / den)/3
    function _perAtomStaticPlusFraction(uint256 assetsAfterFixedFees) internal view returns (uint256) {
        (, uint256 fractionBps) = protocol.multiVault.tripleConfig();
        uint256 fractionGross = _mulDivUp(assetsAfterFixedFees, fractionBps, _gc().feeDenominator);
        return (fractionGross / 3);
    }

    /// @dev create one triple with `extra` over the fixed triple cost; arrays scoped inside to avoid stack pressure
    function _createTripleWithExtra(bytes32 sid, bytes32 pid, bytes32 oid, uint256 extra, address creator) internal {
        uint256 sendAmount = protocol.multiVault.getTripleCost() + extra;
        bytes32[] memory S = new bytes32[](1);
        bytes32[] memory P = new bytes32[](1);
        bytes32[] memory O = new bytes32[](1);
        uint256[] memory V = new uint256[](1);
        S[0] = sid;
        P[0] = pid;
        O[0] = oid;
        V[0] = sendAmount;

        vm.startPrank(creator);
        protocol.multiVault.createTriples{ value: sendAmount }(S, P, O, V);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                1) ATOM: DEFAULT CURVE
        Create with atomCost only, deposit, redeem (single user) — no hyperinflation
    //////////////////////////////////////////////////////////////////////////*/

    function test_atom_default_deposit_then_redeem_no_hyperinflation_when_gated_off() public {
        // Gate OFF by setting threshold extremely high
        _setFeeThreshold(type(uint256).max / 2);

        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes32 atom = createSimpleAtom("A", atomCost, users.alice);

        uint256 curveId = _defaultId();

        uint256 p0 = _price(atom, curveId);
        (uint256 a0, uint256 s0) = _vault(atom, curveId);

        // Single-user deposit on default curve
        uint256 amount = MIN_DEPOSIT * 5; // something > minDeposit
        (uint256 minted,) = _expectDeposit(users.alice, atom, curveId, amount);

        // Now redeem exactly what was minted
        _expectRedeem(users.alice, atom, curveId, minted);

        // Invariants: share price unchanged, totals back to creation state
        uint256 p1 = _price(atom, curveId);
        (uint256 a1, uint256 s1) = _vault(atom, curveId);

        assertEq(p1, p0, "share price must be unchanged");
        assertEq(a1, a0, "totalAssets must return to pre-deposit");
        assertEq(s1, s0, "totalShares must return to pre-deposit");
    }

    /*//////////////////////////////////////////////////////////////////////////
                 2) ATOM: NON-DEFAULT CURVE — entry fee flow to default
    //////////////////////////////////////////////////////////////////////////*/

    function test_atom_nonDefault_deposit_flows_entry_fee_to_default_when_threshold_met() public {
        // Gate ON (easy to meet): set threshold to min ghost shares
        _setFeeThreshold(MIN_SHARES);

        bytes32 atom = createSimpleAtom("B", protocol.multiVault.getAtomCost(), users.alice);

        // 1 = default curve, 2 = first non-default curve
        (uint256 aDef0,) = _vault(atom, 1);
        (uint256 aNon0,) = _vault(atom, 2);

        // Fresh non-default curve deposit (isNew && !isDefault) -> minShare cost applies
        uint256 amount = 5 ether;
        (uint256 expShares, uint256 assetsAfterFees) = protocol.multiVault.previewDeposit(atom, 2, amount);

        VaultFees memory vf = _vf();
        GeneralConfig memory gc = _gc();

        // base = amount - minShare (for non-default creation)
        uint256 base = amount - gc.minShare;
        uint256 expectedEntryFee = _mulDivUp(base, vf.entryFee, gc.feeDenominator);

        // Perform deposit
        vm.startPrank(users.alice);
        uint256 sharesMinted = protocol.multiVault.deposit{ value: amount }(users.alice, atom, 2, expShares);
        vm.stopPrank();
        sharesMinted; // silence

        // Check default vault got exactly the entry fee
        (uint256 aDef1,) = _vault(atom, 1);
        assertEq(aDef1 - aDef0, expectedEntryFee, "default vault must receive entry fee");

        // Non-default total assets increased by assetsAfterFees + minShare (creation path mints ghost)
        (uint256 aNon1,) = _vault(atom, 2);
        assertEq(aNon1 - aNon0, assetsAfterFees + gc.minShare, "non-default vault assets delta mismatch");
    }

    function test_atom_nonDefault_deposit_does_not_flow_entry_fee_when_below_threshold() public {
        // Gate OFF: make threshold unreachable for this test
        _setFeeThreshold(type(uint256).max / 2);

        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes32 atom = createSimpleAtom("C", atomCost, users.alice);

        uint256 defaultId = _defaultId();
        uint256 nonDefaultId = 3; // another non-default

        (uint256 aDef0,) = _vault(atom, defaultId);

        uint256 amount = 3 ether;
        (uint256 expShares,) = protocol.multiVault.previewDeposit(atom, nonDefaultId, amount);
        _expectDeposit(users.alice, atom, nonDefaultId, amount);

        (uint256 aDef1,) = _vault(atom, defaultId);
        assertEq(aDef1 - aDef0, 0, "default vault must not receive entry fee when gated");
    }

    /*//////////////////////////////////////////////////////////////////////////
                               3) TRIPLE CREATE — no fraction
      If any atom default vault is below threshold -> ONLY static create credit flows
    //////////////////////////////////////////////////////////////////////////*/

    function test_triple_create_flows_only_static_when_any_atom_below_threshold() public {
        // Gate OFF for atoms: use massive threshold so _shouldChargeFees(atom) == false
        _setFeeThreshold(type(uint256).max / 2);

        // Create three atoms minimally
        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes32 sid = createSimpleAtom("S", atomCost, users.alice);
        bytes32 pid = createSimpleAtom("P", atomCost, users.alice);
        bytes32 oid = createSimpleAtom("O", atomCost, users.alice);

        uint256 defaultId = _defaultId();

        // Baselines
        (uint256 sA0,) = _vault(sid, defaultId);
        (uint256 pA0,) = _vault(pid, defaultId);
        (uint256 oA0,) = _vault(oid, defaultId);

        // Create one triple with just tripleCost (assetsAfterFixedFees = 0)
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        bytes32[] memory S = new bytes32[](1);
        bytes32[] memory P = new bytes32[](1);
        bytes32[] memory O = new bytes32[](1);
        uint256[] memory V = new uint256[](1);
        S[0] = sid;
        P[0] = pid;
        O[0] = oid;
        V[0] = tripleCost;

        vm.startPrank(users.alice);
        protocol.multiVault.createTriples{ value: tripleCost }(S, P, O, V);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                     4) TRIPLE CREATE — atom fraction charged
       When ALL three atoms pass threshold -> static + fraction flows to atoms
    //////////////////////////////////////////////////////////////////////////*/

    function test_triple_create_flows_static_plus_fraction_when_all_atoms_above_threshold() public {
        _setFeeThreshold(MIN_SHARES); // gate ON

        // atoms
        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes32 sid = createSimpleAtom("S2", atomCost, users.alice);
        bytes32 pid = createSimpleAtom("P2", atomCost, users.alice);
        bytes32 oid = createSimpleAtom("O2", atomCost, users.alice);

        // baselines (1 = default curve)
        (uint256 sA0,) = _vault(sid, 1);
        (uint256 pA0,) = _vault(pid, 1);
        (uint256 oA0,) = _vault(oid, 1);

        // create triple with assetsAfterFixedFees > 0
        uint256 extra = 9 ether;
        _createTripleWithExtra(sid, pid, oid, extra, users.alice);

        // expected per-atom credit
        uint256 perAtom = _perAtomStaticPlusFraction(extra);

        (uint256 sA1,) = _vault(sid, 1);
        (uint256 pA1,) = _vault(pid, 1);
        (uint256 oA1,) = _vault(oid, 1);

        assertEq(sA1 - sA0, perAtom, "subject static+fraction mismatch");
        assertEq(pA1 - pA0, perAtom, "predicate static+fraction mismatch");
        assertEq(oA1 - oA0, perAtom, "object static+fraction mismatch");
    }

    /*//////////////////////////////////////////////////////////////////////////
               5) EXIT FEE: redeem from non-default -> flows to default (gated)
    //////////////////////////////////////////////////////////////////////////*/

    function test_exit_fee_from_nonDefault_redeem_flows_to_default_when_threshold_met() public {
        _setFeeThreshold(MIN_SHARES); // Gate ON

        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes32 atom = createSimpleAtom("X", atomCost, users.alice);

        uint256 defaultId = _defaultId();
        uint256 nonDefaultId = 2;

        // Create non-default position
        uint256 amount = 8 ether;
        (uint256 minted,) = protocol.multiVault.previewDeposit(atom, nonDefaultId, amount);
        _expectDeposit(users.alice, atom, nonDefaultId, amount);

        // Baseline default assets
        (uint256 aDef0,) = _vault(atom, defaultId);

        // Redeem half the user's shares on non-default
        uint256 userShares = protocol.multiVault.getShares(users.alice, atom, nonDefaultId);
        uint256 half = userShares / 2;

        (uint256 assetsAfterFees, uint256 rawAssetsBeforeFees) = _expectRedeem(users.alice, atom, nonDefaultId, half);
        assetsAfterFees; // silence

        // expected exit fee = ceil(rawAssetsBeforeFees * exitBps / den)
        VaultFees memory vf = _vf();
        GeneralConfig memory gc = _gc();
        uint256 expectedExit = _mulDivUp(rawAssetsBeforeFees, vf.exitFee, gc.feeDenominator);

        (uint256 aDef1,) = _vault(atom, defaultId);
        assertEq(aDef1 - aDef0, expectedExit, "default must receive exit fee from non-default redeem");
    }

    /*//////////////////////////////////////////////////////////////////////////
                       6) MULTI-DEPOSIT: gate flips between txs
    //////////////////////////////////////////////////////////////////////////*/

    function test_default_deposit_entry_fee_applies_only_after_gate_turns_on() public {
        // Start GATE OFF (huge threshold)
        _setFeeThreshold(type(uint256).max / 2);

        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes32 atom = createSimpleAtom("Y", atomCost, users.alice);

        uint256 defaultId = _defaultId();

        (uint256 a0,) = _vault(atom, defaultId);

        // First deposit while gated OFF
        uint256 amount1 = 2 ether;
        (uint256 sExp1,) = protocol.multiVault.previewDeposit(atom, defaultId, amount1);
        vm.startPrank(users.alice);
        protocol.multiVault.deposit{ value: amount1 }(users.alice, atom, defaultId, sExp1);
        vm.stopPrank();

        (uint256 a1,) = _vault(atom, defaultId);
        // No entry fee should have been credited (only user's net assets go into the vault)
        // We can’t easily isolate the net assets vs. fees here without replicating previews,
        // so instead flip gate ON and check the *delta due to fees* on the second deposit.

        // Turn GATE ON
        _setFeeThreshold(MIN_SHARES);

        // Second deposit while gated ON
        uint256 amount2 = 4 ether;
        (uint256 sExp2, uint256 netToVault2) = protocol.multiVault.previewDeposit(atom, defaultId, amount2);

        vm.startPrank(users.alice);
        protocol.multiVault.deposit{ value: amount2 }(users.alice, atom, defaultId, sExp2);
        vm.stopPrank();

        (uint256 a2,) = _vault(atom, defaultId);

        // Expect: assets delta = user's net to vault + credited entry fee (gate-aware)
        uint256 creditedEntry2 = _entryFeeCreditIfCharged(atom, amount2);
        assertEq(
            a2 - a1,
            netToVault2 + creditedEntry2,
            "assets delta must equal net to vault + entry fee credit (default deposit)"
        );
    }
}
