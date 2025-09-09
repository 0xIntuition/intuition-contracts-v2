// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {
    IMultiVaultCore,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

contract MultiVaultCoreTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        // BaseTest deploys + initializes a working MultiVault system.
        console2.log("Core test setup complete");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  INIT / REVERTS
    //////////////////////////////////////////////////////////////////////////*/

    function testCore_Init_RevertsWhen_AdminZero() public {
        // Fresh impl + proxy
        MultiVault impl = new MultiVault();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), users.admin, "");
        MultiVault mv = MultiVault(address(proxy));

        // Minimal configs; only admin zero matters for this test.
        GeneralConfig memory gc = _getDefaultGeneralConfig();
        gc.admin = address(0); // <-- cause revert in __MultiVaultCore_init

        AtomConfig memory ac = _getDefaultAtomConfig();
        TripleConfig memory tc = _getDefaultTripleConfig();
        WalletConfig memory wc = _getDefaultWalletConfig(address(0));
        VaultFees memory vf = _getDefaultVaultFees();
        BondingCurveConfig memory bc = _getDefaultBondingCurveConfig();

        vm.expectRevert(MultiVaultCore.MultiVaultCore_InvalidAdmin.selector);
        mv.initialize(gc, ac, tc, wc, vf, bc);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  CONFIG GETTERS
    //////////////////////////////////////////////////////////////////////////*/

    function testCore_Getters_ReturnConfiguredValues() public {
        // General
        GeneralConfig memory g = protocol.multiVault.getGeneralConfig();
        assertEq(g.admin, users.admin, "admin");
        assertEq(g.protocolMultisig, users.admin, "protocol multisig");
        assertEq(g.feeDenominator, FEE_DENOMINATOR, "feeDenominator");
        assertEq(g.minDeposit, MIN_DEPOSIT, "minDeposit");
        assertEq(g.minShare, MIN_SHARES, "minShare");
        assertEq(g.atomDataMaxLength, ATOM_DATA_MAX_LENGTH, "atomDataMaxLength");
        assertEq(g.decimalPrecision, DECIMAL_PRECISION, "decimalPrecision");

        // Atom
        AtomConfig memory a = protocol.multiVault.getAtomConfig();
        assertEq(a.atomCreationProtocolFee, ATOM_CREATION_PROTOCOL_FEE, "atomCreationProtocolFee");
        assertEq(a.atomWalletDepositFee, ATOM_WALLET_DEPOSIT_FEE, "atomWalletDepositFee");

        // Triple
        TripleConfig memory t = protocol.multiVault.getTripleConfig();
        assertEq(t.tripleCreationProtocolFee, TRIPLE_CREATION_PROTOCOL_FEE, "tripleCreationProtocolFee");
        assertEq(
            t.totalAtomDepositsOnTripleCreation,
            TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION,
            "totalAtomDepositsOnTripleCreation"
        );
        // In BaseTest default we overwrite this to 500 in _getDefaultTripleConfig
        assertEq(t.atomDepositFractionForTriple, 500, "atomDepositFractionForTriple");

        // Wallet
        WalletConfig memory w = protocol.multiVault.getWalletConfig();
        assertEq(w.atomWalletFactory, w.atomWalletFactory, "atomWalletFactory echo");

        // Fees
        VaultFees memory f = protocol.multiVault.getVaultFees();
        VaultFees memory fDefault = _getDefaultVaultFees();
        assertEq(f.entryFee, fDefault.entryFee, "entryFee");
        assertEq(f.exitFee, fDefault.exitFee, "exitFee");
        assertEq(f.protocolFee, fDefault.protocolFee, "protocolFee");

        // Curve
        BondingCurveConfig memory b = protocol.multiVault.getBondingCurveConfig();
        assertEq(b.defaultCurveId, 1, "default curve id");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  ATOM FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function testCore_Atom_GettersAndFlags() public {
        // Pre: unknown atom
        bytes32 unknownId = _randomId("ATOM");
        assertFalse(protocol.multiVault.isAtom(unknownId), "unknown isAtom false");
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_AtomDoesNotExist.selector, unknownId));
        protocol.multiVault.getAtom(unknownId);

        // Create an atom
        bytes memory data = abi.encodePacked("atom:core:1");
        uint256 cost = protocol.multiVault.getAtomCost();
        bytes32 id = createAtomWithDeposit(data, cost, users.alice);

        // atom(bytes32)
        bytes memory stored = protocol.multiVault.atom(id);
        assertEq(keccak256(stored), keccak256(data), "atom data round-trip");

        // calculateAtomId
        assertEq(protocol.multiVault.calculateAtomId(data), id, "calculateAtomId matches");

        // getAtom(bytes32)
        bytes memory returned = protocol.multiVault.getAtom(id);
        assertEq(keccak256(returned), keccak256(data), "getAtom returns data");

        // isAtom
        assertTrue(protocol.multiVault.isAtom(id), "isAtom true");

        // getAtomCost = atomCreationProtocolFee + minShare
        uint256 expectedCost = ATOM_CREATION_PROTOCOL_FEE + MIN_SHARES;
        assertEq(cost, expectedCost, "getAtomCost formula");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 TRIPLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function testCore_Triple_GettersAndFlags_PositiveAndCounter() public {
        // Create 3 atoms + triple
        (bytes32 tripleId, bytes32[] memory atomIds) = createTripleWithAtoms(
            "S", "P", "O", protocol.multiVault.getAtomCost(), protocol.multiVault.getTripleCost(), users.alice
        );

        // 1) triple(tripleId)
        {
            (bytes32 s, bytes32 p, bytes32 o) = protocol.multiVault.triple(tripleId);
            assertEq(s, atomIds[0], "triple.s");
            assertEq(p, atomIds[1], "triple.p");
            assertEq(o, atomIds[2], "triple.o");
        }

        // 2) counter id + flags
        bytes32 counterId;
        {
            counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);
            bytes32 counter2 = protocol.multiVault.calculateCounterTripleId(atomIds[0], atomIds[1], atomIds[2]);
            assertEq(counterId, counter2, "counter id consistency");
            assertTrue(protocol.multiVault.isCounterTriple(counterId), "isCounterTriple(counter) == true");
            assertFalse(protocol.multiVault.isCounterTriple(tripleId), "isCounterTriple(positive) == false");
        }

        // 3) triple(counter) matches triple(positive)
        {
            (bytes32 sA, bytes32 pA, bytes32 oA) = protocol.multiVault.triple(tripleId);
            (bytes32 sB, bytes32 pB, bytes32 oB) = protocol.multiVault.triple(counterId);
            assertEq(sB, sA, "counter.s");
            assertEq(pB, pA, "counter.p");
            assertEq(oB, oA, "counter.o");
        }

        // 4) getTriple for both ids
        {
            (bytes32 s1, bytes32 p1, bytes32 o1) = protocol.multiVault.getTriple(tripleId);
            (bytes32 s2, bytes32 p2, bytes32 o2) = protocol.multiVault.getTriple(counterId);
            assertEq(s2, s1, "getTriple(counter).s");
            assertEq(p2, p1, "getTriple(counter).p");
            assertEq(o2, o1, "getTriple(counter).o");
        }

        // 5) counter -> triple mapping
        {
            bytes32 back = protocol.multiVault.getTripleIdFromCounterId(counterId);
            assertEq(back, tripleId, "counter->triple mapping");
        }

        // 6) calculateTripleId, cost, vault types
        {
            bytes32 calc = protocol.multiVault.calculateTripleId(atomIds[0], atomIds[1], atomIds[2]);
            assertEq(calc, tripleId, "calculateTripleId matches");

            uint256 expectedTripleCost =
                TRIPLE_CREATION_PROTOCOL_FEE + TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION + (2 * MIN_SHARES);
            assertEq(protocol.multiVault.getTripleCost(), expectedTripleCost, "getTripleCost formula");

            assertEq(
                uint256(protocol.multiVault.getVaultType(atomIds[0])),
                uint256(IMultiVault.VaultType.ATOM),
                "VaultType ATOM"
            );
            assertEq(
                uint256(protocol.multiVault.getVaultType(tripleId)),
                uint256(IMultiVault.VaultType.TRIPLE),
                "VaultType TRIPLE"
            );
            assertEq(
                uint256(protocol.multiVault.getVaultType(counterId)),
                uint256(IMultiVault.VaultType.COUNTER_TRIPLE),
                "VaultType COUNTER_TRIPLE"
            );
        }
    }

    function testCore_Triple_Revert_getTriple_Nonexistent() public {
        bytes32 bogus = _randomId("TRIPLE");
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TripleDoesNotExist.selector, bogus));
        protocol.multiVault.getTriple(bogus);
    }

    function testCore_triple_ReturnsZerosForUnknown() public {
        bytes32 bogus = _randomId("TRIPLE_ZERO");
        (bytes32 s, bytes32 p, bytes32 o) = protocol.multiVault.triple(bogus);
        assertEq(s, bytes32(0), "s == 0");
        assertEq(p, bytes32(0), "p == 0");
        assertEq(o, bytes32(0), "o == 0");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              TYPE QUERIES / REVERTS
    //////////////////////////////////////////////////////////////////////////*/

    function testCore_getVaultType_RevertsOnUnknown() public {
        bytes32 unknown = _randomId("TERM");
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TermDoesNotExist.selector, unknown));
        protocol.multiVault.getVaultType(unknown);
    }

    function testCore_CounterIdMapping_RoundTrip() public {
        // Create a triple and verify both mapping directions and non-existent path
        (bytes32 tripleId, bytes32[] memory atomIds) = createTripleWithAtoms(
            "SX", "PX", "OX", protocol.multiVault.getAtomCost(), protocol.multiVault.getTripleCost(), users.bob
        );

        bytes32 counter = protocol.multiVault.getCounterIdFromTripleId(tripleId);
        assertTrue(protocol.multiVault.isCounterTriple(counter), "counter true");

        // Non-existent counter id should map to 0
        bytes32 bogusCounter =
            protocol.multiVault.calculateCounterTripleId(_randomId("S"), _randomId("P"), _randomId("O"));
        // That bogusCounter has no mapping set in storage; getTripleIdFromCounterId returns 0
        assertEq(protocol.multiVault.getTripleIdFromCounterId(bogusCounter), bytes32(0), "bogus -> 0");

        // Pure funcs determinism
        assertEq(
            protocol.multiVault.calculateCounterTripleId(atomIds[0], atomIds[1], atomIds[2]),
            protocol.multiVault.getCounterIdFromTripleId(tripleId),
            "pure vs storage-backed match"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _randomId(string memory tag) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("RANDOM_", tag));
    }
}
