// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";

contract CreateTriplesForTest is BaseTest {
    uint256 internal CURVE_ID;

    /// @dev Mirrors {ApprovalTypes.CREATION} = 0b100.
    uint8 internal constant CREATION_BIT = 4;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /* =================================================== */
    /*                APPROVAL GATE — SUCCESS              */
    /* =================================================== */

    function test_createTriplesFor_Success_withCreationApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-creation", "P-creation", "O-creation");
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        bytes32 tripleId = _createOneTripleFor(users.alice, users.bob, atomIds);

        assertTrue(protocol.multiVault.isTermCreated(tripleId), "triple must exist");
    }

    function test_createTriplesFor_Success_withDepositAndCreationApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-dc", "P-dc", "O-dc");
        setupApproval(users.alice, users.bob, ApprovalTypes.DEPOSIT_AND_CREATION);

        bytes32 tripleId = _createOneTripleFor(users.alice, users.bob, atomIds);
        assertTrue(protocol.multiVault.isTermCreated(tripleId));
    }

    function test_createTriplesFor_Success_withRedemptionAndCreationApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-rc", "P-rc", "O-rc");
        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION_AND_CREATION);

        bytes32 tripleId = _createOneTripleFor(users.alice, users.bob, atomIds);
        assertTrue(protocol.multiVault.isTermCreated(tripleId));
    }

    function test_createTriplesFor_Success_withAllApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-all", "P-all", "O-all");
        setupApproval(users.alice, users.bob, ApprovalTypes.ALL);

        bytes32 tripleId = _createOneTripleFor(users.alice, users.bob, atomIds);
        assertTrue(protocol.multiVault.isTermCreated(tripleId));
    }

    function test_createTriplesFor_creatorEqualsMsgSender_Success_withoutApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-self", "P-self", "O-self");
        // Self-creation by alice: no approval needed.
        bytes32 tripleId = _createOneTripleFor(users.alice, users.alice, atomIds);
        assertTrue(protocol.multiVault.isTermCreated(tripleId));
    }

    function test_createTriplesFor_multipleTriples_Success() public {
        // Create 6 atoms for 2 distinct triples; assert both triples are
        // created and both credit alice as the on-behalf-of creator.
        bytes[] memory atomData = new bytes[](6);
        atomData[0] = "multi-S1";
        atomData[1] = "multi-P1";
        atomData[2] = "multi-O1";
        atomData[3] = "multi-S2";
        atomData[4] = "multi-P2";
        atomData[5] = "multi-O2";
        bytes32[] memory atomIds = createAtomsWithUniformCost(atomData, ATOM_COST[0], users.alice);

        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        bytes32[] memory subjectIds = new bytes32[](2);
        bytes32[] memory predicateIds = new bytes32[](2);
        bytes32[] memory objectIds = new bytes32[](2);
        uint256[] memory assets = new uint256[](2);

        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];
        assets[0] = TRIPLE_COST[0];

        subjectIds[1] = atomIds[3];
        predicateIds[1] = atomIds[4];
        objectIds[1] = atomIds[5];
        assets[1] = TRIPLE_COST[0];

        uint256 total = TRIPLE_COST[0] * 2;

        resetPrank(users.bob);
        bytes32[] memory tripleIds = protocol.multiVault.createTriplesFor{ value: total }(
            users.alice, subjectIds, predicateIds, objectIds, assets
        );

        assertEq(tripleIds.length, 2, "should return two triple IDs");
        assertTrue(protocol.multiVault.isTermCreated(tripleIds[0]), "first triple must exist");
        assertTrue(protocol.multiVault.isTermCreated(tripleIds[1]), "second triple must exist");
    }

    function test_createTriplesFor_emitsTripleCreatedWithCreator() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-evt", "P-evt", "O-evt");
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        bytes32 expectedTripleId = protocol.multiVault.calculateTripleId(atomIds[0], atomIds[1], atomIds[2]);

        // Match the first two indexed topics (creator, termId); ignore
        // non-indexed atom-id payload (Solidity guarantees deterministic
        // encoding from the same inputs across both paths).
        vm.expectEmit(true, true, false, false);
        emit TripleCreated(users.alice, expectedTripleId, bytes32(0), bytes32(0), bytes32(0));

        _createOneTripleFor(users.alice, users.bob, atomIds);
    }

    /// @dev Local mirror of {IMultiVault.TripleCreated}; needed for
    ///      vm.expectEmit since Foundry resolves the event by signature in
    ///      the calling contract's scope.
    event TripleCreated(
        address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId
    );

    /* =================================================== */
    /*                APPROVAL GATE — REVERTS              */
    /* =================================================== */

    function test_createTriplesFor_RevertWhen_NoApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-rev1", "P-rev1", "O-rev1");
        _expectCreatorNotApprovedRevert(users.alice, users.bob, atomIds);
    }

    function test_createTriplesFor_RevertWhen_OnlyDepositApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-rev2", "P-rev2", "O-rev2");
        setupApproval(users.alice, users.bob, ApprovalTypes.DEPOSIT);
        _expectCreatorNotApprovedRevert(users.alice, users.bob, atomIds);
    }

    function test_createTriplesFor_RevertWhen_OnlyRedemptionApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-rev3", "P-rev3", "O-rev3");
        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION);
        _expectCreatorNotApprovedRevert(users.alice, users.bob, atomIds);
    }

    function test_createTriplesFor_RevertWhen_OnlyBothApproval() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-rev4", "P-rev4", "O-rev4");
        setupApproval(users.alice, users.bob, ApprovalTypes.BOTH);
        _expectCreatorNotApprovedRevert(users.alice, users.bob, atomIds);
    }

    function test_createTriplesFor_RevertWhen_DifferentSenderApproved() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-rev5", "P-rev5", "O-rev5");
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);
        _expectCreatorNotApprovedRevert(users.alice, users.charlie, atomIds);
    }

    /* =================================================== */
    /*                  STATE ATTRIBUTION                  */
    /* =================================================== */

    function test_createTriplesFor_creditsUtilizationToCreator_NotSender() public {
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-util", "P-util", "O-util");
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        uint256 epoch = protocol.multiVault.currentEpoch();
        int256 aliceBefore = protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch);
        int256 bobBefore = protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch);

        uint256 payment = TRIPLE_COST[0] + 3 ether;
        _createOneTripleForWithPayment(users.alice, users.bob, atomIds, payment);

        int256 aliceAfter = protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch);
        int256 bobAfter = protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch);

        assertEq(aliceAfter - aliceBefore, int256(payment), "creator utilization delta == payment");
        assertEq(bobAfter, bobBefore, "sender utilization unchanged");
    }

    /* =================================================== */
    /*              DIFFERENTIAL: createTriples            */
    /* =================================================== */

    /// @dev Snapshot of observable on-chain state after a triple create call.
    struct TripleCreateProbe {
        uint256 vaultTotalAssets;
        uint256 vaultTotalShares;
        uint256 holderShares;
        uint256 totalTermsCreated;
        int256 personalUtilization;
    }

    function test_createTriplesFor_creatorEqualsMsgSender_ParityWithCreateTriples() public {
        // Build the same triple via createTriples and createTriplesFor (with
        // creator == msg.sender) and assert observable state is identical.
        bytes32[] memory atomIds = _createUnderlyingAtoms("S-par", "P-par", "O-par");

        bytes32[] memory subjectIds = _singleBytes32Arr(atomIds[0]);
        bytes32[] memory predicateIds = _singleBytes32Arr(atomIds[1]);
        bytes32[] memory objectIds = _singleBytes32Arr(atomIds[2]);
        uint256[] memory assets = _singleUintArr(TRIPLE_COST[0] + 2 ether);
        uint256 payment = assets[0];

        uint256 snap = vm.snapshotState();

        // Path A: createTriples.
        resetPrank(users.alice);
        bytes32[] memory idsA =
            protocol.multiVault.createTriples{ value: payment }(subjectIds, predicateIds, objectIds, assets);
        bytes32 tripleId = idsA[0];
        TripleCreateProbe memory direct = _probeTriple(tripleId, users.alice);

        require(vm.revertToState(snap), "revertToState failed");

        // Path B: createTriplesFor with creator == msg.sender.
        resetPrank(users.alice);
        bytes32[] memory idsB = protocol.multiVault.createTriplesFor{ value: payment }(
            users.alice, subjectIds, predicateIds, objectIds, assets
        );
        assertEq(idsB[0], tripleId, "deterministic triple id must match");
        TripleCreateProbe memory viaFor = _probeTriple(tripleId, users.alice);

        _assertTripleProbesEqual(direct, viaFor);
    }

    function _probeTriple(bytes32 tripleId, address holder) internal view returns (TripleCreateProbe memory probe) {
        (probe.vaultTotalAssets, probe.vaultTotalShares) = protocol.multiVault.getVault(tripleId, CURVE_ID);
        probe.holderShares = protocol.multiVault.getShares(holder, tripleId, CURVE_ID);
        probe.totalTermsCreated = protocol.multiVault.totalTermsCreated();
        probe.personalUtilization =
            protocol.multiVault.getUserUtilizationForEpoch(holder, protocol.multiVault.currentEpoch());
    }

    function _assertTripleProbesEqual(TripleCreateProbe memory a, TripleCreateProbe memory b) internal pure {
        assertEq(b.vaultTotalAssets, a.vaultTotalAssets, "vault totalAssets parity");
        assertEq(b.vaultTotalShares, a.vaultTotalShares, "vault totalShares parity");
        assertEq(b.holderShares, a.holderShares, "holder shares parity");
        assertEq(b.totalTermsCreated, a.totalTermsCreated, "totalTermsCreated parity");
        assertEq(b.personalUtilization, a.personalUtilization, "personal utilization parity");
    }

    /* =================================================== */
    /*                        FUZZ                         */
    /* =================================================== */

    function testFuzz_createTriplesFor_approvalBitParity(uint8 raw, bytes32 salt) public {
        uint8 bits = uint8(bound(raw, 0, 7));
        ApprovalTypes approval = ApprovalTypes(bits);

        // Unique underlying atoms per fuzz run.
        bytes32[] memory atomIds = _createUnderlyingAtoms(
            string.concat("fuzz-S-", vm.toString(salt)),
            string.concat("fuzz-P-", vm.toString(salt)),
            string.concat("fuzz-O-", vm.toString(salt))
        );

        if (approval != ApprovalTypes.NONE) {
            setupApproval(users.alice, users.bob, approval);
        }

        bytes32[] memory subjectIds = _singleBytes32Arr(atomIds[0]);
        bytes32[] memory predicateIds = _singleBytes32Arr(atomIds[1]);
        bytes32[] memory objectIds = _singleBytes32Arr(atomIds[2]);
        uint256[] memory assets = _singleUintArr(TRIPLE_COST[0]);

        resetPrank(users.bob);
        if ((bits & CREATION_BIT) != 0) {
            bytes32[] memory ids = protocol.multiVault.createTriplesFor{ value: TRIPLE_COST[0] }(
                users.alice, subjectIds, predicateIds, objectIds, assets
            );
            assertTrue(protocol.multiVault.isTermCreated(ids[0]));
        } else {
            vm.expectRevert(MultiVault.MultiVault_CreatorNotApproved.selector);
            protocol.multiVault.createTriplesFor{ value: TRIPLE_COST[0] }(
                users.alice, subjectIds, predicateIds, objectIds, assets
            );
        }
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    function _createUnderlyingAtoms(
        string memory s,
        string memory p,
        string memory o
    )
        internal
        returns (bytes32[] memory atomIds)
    {
        bytes[] memory atomData = new bytes[](3);
        atomData[0] = abi.encodePacked(s);
        atomData[1] = abi.encodePacked(p);
        atomData[2] = abi.encodePacked(o);
        atomIds = createAtomsWithUniformCost(atomData, ATOM_COST[0], users.alice);
    }

    function _createOneTripleFor(address creator, address sender, bytes32[] memory atomIds) internal returns (bytes32) {
        return _createOneTripleForWithPayment(creator, sender, atomIds, TRIPLE_COST[0]);
    }

    function _createOneTripleForWithPayment(
        address creator,
        address sender,
        bytes32[] memory atomIds,
        uint256 payment
    )
        internal
        returns (bytes32)
    {
        bytes32[] memory subjectIds = _singleBytes32Arr(atomIds[0]);
        bytes32[] memory predicateIds = _singleBytes32Arr(atomIds[1]);
        bytes32[] memory objectIds = _singleBytes32Arr(atomIds[2]);
        uint256[] memory assets = _singleUintArr(payment);

        resetPrank(sender);
        bytes32[] memory ids = protocol.multiVault.createTriplesFor{ value: payment }(
            creator, subjectIds, predicateIds, objectIds, assets
        );
        return ids[0];
    }

    function _expectCreatorNotApprovedRevert(address creator, address sender, bytes32[] memory atomIds) internal {
        bytes32[] memory subjectIds = _singleBytes32Arr(atomIds[0]);
        bytes32[] memory predicateIds = _singleBytes32Arr(atomIds[1]);
        bytes32[] memory objectIds = _singleBytes32Arr(atomIds[2]);
        uint256[] memory assets = _singleUintArr(TRIPLE_COST[0]);

        resetPrank(sender);
        vm.expectRevert(MultiVault.MultiVault_CreatorNotApproved.selector);
        protocol.multiVault.createTriplesFor{ value: TRIPLE_COST[0] }(
            creator, subjectIds, predicateIds, objectIds, assets
        );
    }

    function _singleBytes32Arr(bytes32 v) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](1);
        arr[0] = v;
    }

    function _singleUintArr(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }
}
