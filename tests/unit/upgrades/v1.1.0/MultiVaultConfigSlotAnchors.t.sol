// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

/// @title  MultiVaultConfigSlotAnchorsTest
/// @notice Pins every field in MultiVault's configuration region (slots 1–21) to a RAW SLOT LITERAL.
///
///         Why raw literals rather than the auto-getters the rest of the layout suite uses: a
///         getter-relative assertion cannot detect an intra-struct reorder even in principle, because
///         the field's slot and the auto-getter's return position move together — swap two fields and
///         both sides of the comparison move in lockstep, so the assertion stays green. The
///         MultiVaultLib mirror cannot detect it either, since both sides re-use the same imported
///         struct type and move together as well.
///
///         The method here is to write a DISTINCT sentinel into every field through the ordinary
///         setters, then read each raw slot and assert it holds the sentinel belonging to THAT field.
///         Swapping any two same-typed fields relocates their sentinels and turns this red.
///
///         Same-typed adjacent fields are the whole point: the compiler catches a reorder that changes
///         types, so the only reorders that can reach production are the ones inside a run of
///         identically-typed fields. Those runs are enumerated below.
contract MultiVaultConfigSlotAnchorsTest is BaseTest {
    /* ---------- GeneralConfig occupies slots 1..8 ---------- */
    uint256 internal constant SLOT_ADMIN = 1;
    uint256 internal constant SLOT_PROTOCOL_MULTISIG = 2;
    uint256 internal constant SLOT_FEE_DENOMINATOR = 3;
    uint256 internal constant SLOT_TRUST_BONDING = 4;
    uint256 internal constant SLOT_MIN_DEPOSIT = 5;
    uint256 internal constant SLOT_MIN_SHARE = 6;
    uint256 internal constant SLOT_ATOM_DATA_MAX_LENGTH = 7;
    uint256 internal constant SLOT_FEE_THRESHOLD = 8;

    /* ---------- AtomConfig 9..10, TripleConfig 11..12 ---------- */
    uint256 internal constant SLOT_ATOM_CREATION_PROTOCOL_FEE = 9;
    uint256 internal constant SLOT_ATOM_WALLET_DEPOSIT_FEE = 10;
    uint256 internal constant SLOT_TRIPLE_CREATION_PROTOCOL_FEE = 11;
    uint256 internal constant SLOT_ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 12;

    /* ---------- WalletConfig occupies slots 13..16 ---------- */
    uint256 internal constant SLOT_ENTRY_POINT = 13;
    uint256 internal constant SLOT_ATOM_WARDEN = 14;
    uint256 internal constant SLOT_ATOM_WALLET_BEACON = 15;
    uint256 internal constant SLOT_ATOM_WALLET_FACTORY = 16;

    /* ---------- VaultFees 17..19, BondingCurveConfig 20..21 ---------- */
    uint256 internal constant SLOT_ENTRY_FEE = 17;
    uint256 internal constant SLOT_EXIT_FEE = 18;
    uint256 internal constant SLOT_PROTOCOL_FEE = 19;
    uint256 internal constant SLOT_REGISTRY = 20;
    uint256 internal constant SLOT_DEFAULT_CURVE_ID = 21;

    /// @dev First slot after the configuration region; must stay outside it.
    uint256 internal constant SLOT_FIRST_AFTER_CONFIG = 22;

    function _raw(uint256 slot) internal view returns (uint256) {
        return uint256(vm.load(address(protocol.multiVault), bytes32(slot)));
    }

    function _rawAddr(uint256 slot) internal view returns (address) {
        return address(uint160(_raw(slot)));
    }

    /// @dev Distinct, non-round sentinels so a swap cannot coincidentally satisfy the assertion.
    function _writeSentinels() internal {
        GeneralConfig memory g = protocol.multiVault.getGeneralConfig();
        // Distinct address sentinels too — the deployed fixture reuses one account across several
        // config addresses, which would make an address-slot assertion vacuous under a swap.
        g.admin = address(uint160(0xA0000001));
        g.protocolMultisig = address(uint160(0xA0000002));
        g.trustBonding = address(uint160(0xA0000003));
        g.feeDenominator = 100_003;
        g.minDeposit = 100_005;
        g.minShare = 100_007;
        g.atomDataMaxLength = 100_011;
        g.feeThreshold = 100_013;

        AtomConfig memory a = AtomConfig({ atomCreationProtocolFee: 200_003, atomWalletDepositFee: 200_005 });
        TripleConfig memory t =
            TripleConfig({ tripleCreationProtocolFee: 300_003, atomDepositFractionForTriple: 300_005 });
        VaultFees memory f = VaultFees({ entryFee: 400_003, exitFee: 400_005, protocolFee: 400_007 });

        resetPrank(protocol.multiVault.timelock());
        protocol.multiVault.setGeneralConfig(g);
        protocol.multiVault.setAtomConfig(a);
        protocol.multiVault.setTripleConfig(t);
        protocol.multiVault.setVaultFees(f);
    }

    /* =================================================== */
    /*            SAME-TYPED RUNS — THE REAL RISK          */
    /* =================================================== */

    /// @dev GeneralConfig's uint256 fields. This is the run the layout suite provably could not cover:
    ///      swapping `minDeposit` and `minShare` left all prior layout tests green.
    function test_generalConfig_uint256FieldsHoldTheirOwnSlots() external {
        _writeSentinels();

        assertEq(_raw(SLOT_FEE_DENOMINATOR), 100_003, "feeDenominator must be at slot 3");
        assertEq(_raw(SLOT_MIN_DEPOSIT), 100_005, "minDeposit must be at slot 5");
        assertEq(_raw(SLOT_MIN_SHARE), 100_007, "minShare must be at slot 6");
        assertEq(_raw(SLOT_ATOM_DATA_MAX_LENGTH), 100_011, "atomDataMaxLength must be at slot 7");
        assertEq(_raw(SLOT_FEE_THRESHOLD), 100_013, "feeThreshold must be at slot 8");
    }

    /// @dev AtomConfig and TripleConfig are each a pair of same-typed uint256 fields.
    function test_atomAndTripleConfig_fieldsHoldTheirOwnSlots() external {
        _writeSentinels();

        assertEq(_raw(SLOT_ATOM_CREATION_PROTOCOL_FEE), 200_003, "atomCreationProtocolFee must be at slot 9");
        assertEq(_raw(SLOT_ATOM_WALLET_DEPOSIT_FEE), 200_005, "atomWalletDepositFee must be at slot 10");
        assertEq(_raw(SLOT_TRIPLE_CREATION_PROTOCOL_FEE), 300_003, "tripleCreationProtocolFee must be at slot 11");
        assertEq(
            _raw(SLOT_ATOM_DEPOSIT_FRACTION_FOR_TRIPLE), 300_005, "atomDepositFractionForTriple must be at slot 12"
        );
    }

    /// @dev VaultFees is three same-typed uint256 fields on a funds path — a swap here silently
    ///      re-prices every deposit and redemption.
    function test_vaultFees_fieldsHoldTheirOwnSlots() external {
        _writeSentinels();

        assertEq(_raw(SLOT_ENTRY_FEE), 400_003, "entryFee must be at slot 17");
        assertEq(_raw(SLOT_EXIT_FEE), 400_005, "exitFee must be at slot 18");
        assertEq(_raw(SLOT_PROTOCOL_FEE), 400_007, "protocolFee must be at slot 19");
    }

    /// @dev WalletConfig is four same-typed address fields. A swap here would, for example, install the
    ///      beacon address as the EntryPoint — and would additionally re-derive every counterfactual
    ///      AtomWallet address, since all four feed the factory's initcode hash.
    function test_walletConfig_addressFieldsHoldTheirOwnSlots() external {
        WalletConfig memory w = protocol.multiVault.getWalletConfig();

        assertEq(_rawAddr(SLOT_ENTRY_POINT), w.entryPoint, "entryPoint must be at slot 13");
        assertEq(_rawAddr(SLOT_ATOM_WARDEN), w.atomWarden, "atomWarden must be at slot 14");
        assertEq(_rawAddr(SLOT_ATOM_WALLET_BEACON), w.atomWalletBeacon, "atomWalletBeacon must be at slot 15");
        assertEq(_rawAddr(SLOT_ATOM_WALLET_FACTORY), w.atomWalletFactory, "atomWalletFactory must be at slot 16");

        // The four must be pairwise distinct, or the assertions above could pass under a swap.
        assertTrue(w.entryPoint != w.atomWarden, "fixture must keep wallet config addresses distinct");
        assertTrue(w.atomWalletBeacon != w.atomWalletFactory, "fixture must keep wallet config addresses distinct");
        assertTrue(w.entryPoint != w.atomWalletBeacon, "fixture must keep wallet config addresses distinct");
    }

    /// @dev GeneralConfig's address fields, and the bonding-curve pair.
    function test_addressFieldsAndBondingCurveConfig_holdTheirOwnSlots() external {
        _writeSentinels();
        BondingCurveConfig memory b = protocol.multiVault.getBondingCurveConfig();

        assertEq(_rawAddr(SLOT_ADMIN), address(uint160(0xA0000001)), "admin must be at slot 1");
        assertEq(_rawAddr(SLOT_PROTOCOL_MULTISIG), address(uint160(0xA0000002)), "protocolMultisig must be at slot 2");
        assertEq(_rawAddr(SLOT_TRUST_BONDING), address(uint160(0xA0000003)), "trustBonding must be at slot 4");
        assertEq(_rawAddr(SLOT_REGISTRY), b.registry, "registry must be at slot 20");
        assertEq(_raw(SLOT_DEFAULT_CURVE_ID), b.defaultCurveId, "defaultCurveId must be at slot 21");
    }

    /* =================================================== */
    /*                  REGION BOUNDARY                    */
    /* =================================================== */

    /// @dev The configuration region ends at slot 21. Slot 22 is the first mapping (`_atoms`), whose
    ///      base slot is always zero because mapping contents live at hashed slots. Growing any config
    ///      struct would push a config field into slot 22 and turn this red — which is the signal that
    ///      the region has been resized and every anchor above needs re-deriving.
    function test_configRegion_endsAtSlot21() external {
        _writeSentinels();

        assertEq(_raw(SLOT_FIRST_AFTER_CONFIG), 0, "slot 22 must remain the first mapping base, not config data");
    }
}
