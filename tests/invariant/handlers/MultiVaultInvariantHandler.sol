// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

/// @title  MultiVaultInvariantHandler
/// @author 0xIntuition
/// @notice Bounded action driver for the MultiVault stateful invariant campaign. Each public function
///         is a fuzzed user action that the Foundry invariant runner (and Medusa, via the same harness)
///         calls in random sequences. Actions are restricted to a small set of funded actors and credit
///         shares only to the acting account, so the share- and value-conservation invariants can be
///         checked against a closed accounting frame.
/// @dev    The handler tracks every native-value movement into and out of {MultiVault} in
///         `ghost_valueIn` / `ghost_valueOut`, updated ONLY on a successful (non-reverting) action.
///         Because nothing in the campaign sweeps accrued fees, `MultiVault.balance` must always equal
///         `ghost_valueIn - ghost_valueOut`; the multicall drivers below are the
///         primary stress on that identity. Reverts from bounded-but-invalid inputs are swallowed so
///         the campaign keeps exploring. Test-only; never deployed on-chain.
contract MultiVaultInvariantHandler is Test {
    /* ============ IMMUTABLES ============ */

    MultiVault internal immutable MULTI_VAULT;
    uint256 internal immutable DEFAULT_CURVE_ID;

    /* ============ ACTORS ============ */

    /// @dev Fixed, closed set of share-holding actors. Every deposit credits the acting actor only.
    address[3] internal actors;

    /* ============ TERM REGISTRIES ============ */

    bytes32[] public atomTerms;
    bytes32[] public tripleTerms; // positive-side triple ids; counter side derived on demand
    mapping(bytes32 termId => bool known) internal knownTerm;

    /* ============ GHOST ACCOUNTING ============ */

    /// @dev Total native value successfully moved INTO MultiVault (creates + deposits + payable batches).
    uint256 public ghost_valueIn;
    /// @dev Total native value successfully returned OUT of MultiVault to actors (redeem proceeds).
    uint256 public ghost_valueOut;

    uint256 public ghost_atomsCreated;
    uint256 public ghost_triplesCreated;
    uint256 public ghost_deposits;
    uint256 public ghost_redeems;
    uint256 public ghost_valueBearingMulticallBatches;
    uint256 public ghost_multicallRedeemBatches;
    uint256 internal dataNonce;

    /* ============ CONSTRUCTOR ============ */

    constructor(MultiVault multiVault_, uint256 defaultCurveId_, address a0, address a1, address a2) {
        MULTI_VAULT = multiVault_;
        DEFAULT_CURVE_ID = defaultCurveId_;
        actors[0] = a0;
        actors[1] = a1;
        actors[2] = a2;
    }

    /* ============ VIEW HELPERS (consumed by invariants) ============ */

    function actorAt(uint256 index) external view returns (address) {
        return actors[index % actors.length];
    }

    function actorCount() external pure returns (uint256) {
        return 3;
    }

    function atomTermsLength() external view returns (uint256) {
        return atomTerms.length;
    }

    function tripleTermsLength() external view returns (uint256) {
        return tripleTerms.length;
    }

    /* ============ SINGLE-CALL ACTIONS ============ */

    /// @notice Create a single atom vault, funding the actor with a healthy deposit margin.
    function createAtom(uint256 actorSeed, uint256 assetSeed) public {
        address actor = _actor(actorSeed);
        uint256 assets = _boundCreateAssets(assetSeed, MULTI_VAULT.getAtomCost());

        bytes[] memory data = new bytes[](1);
        data[0] = _freshAtomData();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

        vm.deal(actor, assets);
        vm.prank(actor);
        try MULTI_VAULT.createAtoms{ value: assets }(data, amounts) returns (bytes32[] memory ids) {
            _register(atomTerms, ids[0]);
            ghost_valueIn += assets;
            ghost_atomsCreated++;
        } catch { }
    }

    /// @notice Create a triple from three distinct, already-created atoms.
    function createTriple(uint256 actorSeed, uint256 subjectSeed, uint256 predicateSeed, uint256 objectSeed) public {
        uint256 atomCount = atomTerms.length;
        if (atomCount < 3) return;

        bytes32 subjectId = atomTerms[subjectSeed % atomCount];
        bytes32 predicateId = atomTerms[predicateSeed % atomCount];
        bytes32 objectId = atomTerms[objectSeed % atomCount];
        if (subjectId == predicateId || predicateId == objectId || subjectId == objectId) return;

        address actor = _actor(actorSeed);
        uint256 tripleCost = MULTI_VAULT.getTripleCost();

        (bytes32[] memory s, bytes32[] memory p, bytes32[] memory o) = _singletons(subjectId, predicateId, objectId);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = tripleCost;

        vm.deal(actor, tripleCost);
        vm.prank(actor);
        try MULTI_VAULT.createTriples{ value: tripleCost }(s, p, o, amounts) returns (bytes32[] memory ids) {
            _register(tripleTerms, ids[0]);
            ghost_valueIn += tripleCost;
            ghost_triplesCreated++;
        } catch { }
    }

    /// @notice Deposit into an existing atom or triple vault, crediting shares to the acting actor.
    function deposit(uint256 actorSeed, uint256 termSeed, uint256 assetSeed, bool useTriple) public {
        bytes32 termId = _pickTerm(termSeed, useTriple);
        if (termId == bytes32(0)) return;
        _deposit(_actor(actorSeed), termId, _boundDeposit(assetSeed));
    }

    /// @notice Deposit into the counter side of an existing triple. Exercises the counter-stake guard:
    ///         if the actor already holds the positive side on the same curve, this must revert.
    function depositCounter(uint256 actorSeed, uint256 termSeed, uint256 assetSeed) public {
        uint256 tripleCount = tripleTerms.length;
        if (tripleCount == 0) return;
        bytes32 counterId = MULTI_VAULT.getCounterIdFromTripleId(tripleTerms[termSeed % tripleCount]);
        _deposit(_actor(actorSeed), counterId, _boundDeposit(assetSeed));
    }

    /// @notice Redeem a bounded slice of the acting actor's shares in a chosen vault.
    function redeem(uint256 actorSeed, uint256 termSeed, uint256 shareSeed, bool useTriple) public {
        bytes32 termId = _pickTerm(termSeed, useTriple);
        if (termId == bytes32(0)) return;

        address actor = _actor(actorSeed);
        uint256 balance = MULTI_VAULT.getShares(actor, termId, DEFAULT_CURVE_ID);
        if (balance == 0) return;
        uint256 shares = bound(shareSeed, 1, balance);

        vm.prank(actor);
        try MULTI_VAULT.redeem(actor, termId, DEFAULT_CURVE_ID, shares, 0) returns (uint256 assets) {
            ghost_valueOut += assets;
            ghost_redeems++;
        } catch { }
    }

    /* ==================== MULTICALL ACTIONS ==================== */

    /// @notice Drive `multicall` with two deposit sub-calls whose per-sub-call `values` sum to
    ///         `msg.value`. This is the primary stress on the per-sub-call value allocation
    ///         (`_virtualMsgValue` / `_effectiveMsgValue`): if a sub-call ever duplicated or borrowed
    ///         value, the native-value-conservation invariant would break.
    function multicallDeposits(
        uint256 actorSeed,
        uint256 termSeedA,
        uint256 termSeedB,
        uint256 assetSeedA,
        uint256 assetSeedB,
        bool useTripleA,
        bool useTripleB
    ) public {
        bytes32 termA = _pickTerm(termSeedA, useTripleA);
        bytes32 termB = _pickTerm(termSeedB, useTripleB);
        if (termA == bytes32(0) || termB == bytes32(0)) return;

        address actor = _actor(actorSeed);
        uint256 valueA = _boundDeposit(assetSeedA);
        uint256 valueB = _boundDeposit(assetSeedB);
        uint256 total = valueA + valueB;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (actor, termA, DEFAULT_CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (actor, termB, DEFAULT_CURVE_ID, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = valueA;
        values[1] = valueB;

        vm.deal(actor, total);
        vm.prank(actor);
        try MULTI_VAULT.multicall{ value: total }(data, values) {
            ghost_valueIn += total;
            ghost_valueBearingMulticallBatches++;
        } catch { }
    }

    /// @notice Drive `multicall` batching a fresh `createAtoms` with a `deposit` into an existing
    ///         vault, each allocated its own slice of `msg.value`. Mixes a create and a deposit in one
    ///         payable batch — the multi-selector value-accounting path.
    function multicallCreateAndDeposit(uint256 actorSeed, uint256 termSeed, uint256 assetSeed, bool useTriple) public {
        bytes32 termId = _pickTerm(termSeed, useTriple);
        if (termId == bytes32(0)) return;

        address actor = _actor(actorSeed);
        uint256 createValue = _boundCreateAssets(assetSeed, MULTI_VAULT.getAtomCost());
        uint256 depositValue = _boundDeposit(assetSeed >> 1);
        uint256 total = createValue + depositValue;

        bytes[] memory atomData = new bytes[](1);
        atomData[0] = _freshAtomData();
        uint256[] memory createAmounts = new uint256[](1);
        createAmounts[0] = createValue;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomData, createAmounts));
        data[1] = abi.encodeCall(IMultiVault.deposit, (actor, termId, DEFAULT_CURVE_ID, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = createValue;
        values[1] = depositValue;

        vm.deal(actor, total);
        vm.prank(actor);
        try MULTI_VAULT.multicall{ value: total }(data, values) returns (bytes[] memory results) {
            bytes32[] memory createdIds = abi.decode(results[0], (bytes32[]));
            _register(atomTerms, createdIds[0]);
            ghost_valueIn += total;
            ghost_valueBearingMulticallBatches++;
        } catch { }
    }

    /// @notice Drive canonical (non-payable) `multicall` batching two redeems of the actor's shares.
    ///         Confirms canonical multicall carries no value and that batched redeem proceeds are
    ///         accounted exactly like single redeems.
    function multicallRedeem(uint256 actorSeed, uint256 termSeedA, uint256 termSeedB, uint256 shareSeed) public {
        bytes32 termA = _pickTerm(termSeedA, false);
        bytes32 termB = _pickTerm(termSeedB, true);
        if (termA == bytes32(0) || termB == bytes32(0)) return;

        address actor = _actor(actorSeed);
        uint256 balanceA = MULTI_VAULT.getShares(actor, termA, DEFAULT_CURVE_ID);
        uint256 balanceB = MULTI_VAULT.getShares(actor, termB, DEFAULT_CURVE_ID);
        if (balanceA == 0 || balanceB == 0) return;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.redeem, (actor, termA, DEFAULT_CURVE_ID, bound(shareSeed, 1, balanceA), 0));
        data[1] = abi.encodeCall(IMultiVault.redeem, (actor, termB, DEFAULT_CURVE_ID, bound(shareSeed, 1, balanceB), 0));

        vm.prank(actor);
        try MULTI_VAULT.multicall(data, new uint256[](data.length)) returns (bytes[] memory results) {
            ghost_valueOut += abi.decode(results[0], (uint256));
            ghost_valueOut += abi.decode(results[1], (uint256));
            ghost_multicallRedeemBatches++;
        } catch { }
    }

    /* ============ INTERNAL ============ */

    function _deposit(address actor, bytes32 termId, uint256 assets) internal {
        vm.deal(actor, assets);
        vm.prank(actor);
        try MULTI_VAULT.deposit{ value: assets }(actor, termId, DEFAULT_CURVE_ID, 0) {
            ghost_valueIn += assets;
            ghost_deposits++;
        } catch { }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _pickTerm(uint256 termSeed, bool useTriple) internal view returns (bytes32) {
        if (useTriple) {
            uint256 len = tripleTerms.length;
            return len == 0 ? bytes32(0) : tripleTerms[termSeed % len];
        }
        uint256 atomLen = atomTerms.length;
        return atomLen == 0 ? bytes32(0) : atomTerms[termSeed % atomLen];
    }

    /// @dev Fund creation with a margin above the bare creation cost so the post-fee residual clears
    ///      the min-share cost (a bare cost leaves exactly the min-share cost and reverts).
    function _boundCreateAssets(uint256 seed, uint256 cost) internal view returns (uint256) {
        uint256 minDeposit = MULTI_VAULT.getGeneralConfig().minDeposit;
        return bound(seed, cost + minDeposit, cost + 100 ether);
    }

    function _boundDeposit(uint256 seed) internal view returns (uint256) {
        return bound(seed, MULTI_VAULT.getGeneralConfig().minDeposit, 100 ether);
    }

    function _freshAtomData() internal returns (bytes memory) {
        return abi.encodePacked("inv-atom-", dataNonce++);
    }

    function _register(bytes32[] storage registry, bytes32 termId) internal {
        if (!knownTerm[termId]) {
            knownTerm[termId] = true;
            registry.push(termId);
        }
    }

    function _singletons(bytes32 a, bytes32 b, bytes32 c)
        internal
        pure
        returns (bytes32[] memory s, bytes32[] memory p, bytes32[] memory o)
    {
        s = new bytes32[](1);
        p = new bytes32[](1);
        o = new bytes32[](1);
        s[0] = a;
        p[0] = b;
        o[0] = c;
    }
}
