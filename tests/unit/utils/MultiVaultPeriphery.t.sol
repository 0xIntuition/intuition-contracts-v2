// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVaultPeriphery } from "src/utils/MultiVaultPeriphery.sol";
import { IMultiVaultPeriphery } from "src/interfaces/IMultiVaultPeriphery.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { Multicall3 } from "src/external/multicall/Multicall3.sol";

contract RefundFailureMock {
    receive() external payable {
        revert("RefundFailureMock: refund failed");
    }
}

contract MultiVaultPeripheryTest is BaseTest {
    MultiVaultPeriphery public peripheryImpl;
    TransparentUpgradeableProxy public peripheryProxy;
    MultiVaultPeriphery public periphery;

    RefundFailureMock public refundFailureMock;

    function setUp() public override {
        super.setUp();

        peripheryImpl = new MultiVaultPeriphery();
        peripheryProxy = new TransparentUpgradeableProxy(address(peripheryImpl), users.admin, "");
        periphery = MultiVaultPeriphery(address(peripheryProxy));

        periphery.initialize(users.admin, address(protocol.multiVault));

        refundFailureMock = new RefundFailureMock();
        vm.deal(address(refundFailureMock), 100 ether);
    }

    /* =================================================== */
    /*                 INITIALIZE TESTS                    */
    /* =================================================== */

    function test_initialize_successful() external {
        MultiVaultPeriphery newPeriphery = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newPeriphery), users.admin, "");
        MultiVaultPeriphery newPeripheryInstance = MultiVaultPeriphery(address(newProxy));

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.MultiVaultSet(address(protocol.multiVault));

        newPeripheryInstance.initialize(users.alice, address(protocol.multiVault));

        assertEq(address(newPeripheryInstance.multiVault()), address(protocol.multiVault));
        assertEq(address(newPeripheryInstance.multiVaultCore()), address(protocol.multiVault));
        assertTrue(newPeripheryInstance.hasRole(newPeripheryInstance.DEFAULT_ADMIN_ROLE(), users.alice));
    }

    function test_initialize_revertsOnZeroAddressAdmin() external {
        MultiVaultPeriphery newPeriphery = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newPeriphery), users.admin, "");
        MultiVaultPeriphery newPeripheryInstance = MultiVaultPeriphery(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlBadConfirmation.selector));
        newPeripheryInstance.initialize(address(0), address(protocol.multiVault));
    }

    function test_initialize_revertsOnZeroAddressMultiVault() external {
        MultiVaultPeriphery newPeriphery = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newPeriphery), users.admin, "");
        MultiVaultPeriphery newPeripheryInstance = MultiVaultPeriphery(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        newPeripheryInstance.initialize(users.alice, address(0));
    }

    function test_initialize_revertsOnReinitialize() external {
        vm.expectRevert();
        periphery.initialize(users.alice, address(protocol.multiVault));
    }

    function testFuzz_initialize(address admin, address multiVault) external {
        vm.assume(admin != address(0));
        vm.assume(multiVault != address(0));

        MultiVaultPeriphery newPeriphery = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newPeriphery), users.admin, "");
        MultiVaultPeriphery newPeripheryInstance = MultiVaultPeriphery(address(newProxy));

        newPeripheryInstance.initialize(admin, multiVault);

        assertEq(address(newPeripheryInstance.multiVault()), multiVault);
        assertEq(address(newPeripheryInstance.multiVaultCore()), multiVault);
        assertTrue(newPeripheryInstance.hasRole(newPeripheryInstance.DEFAULT_ADMIN_ROLE(), admin));
    }

    /* =================================================== */
    /*               SET MULTIVAULT TESTS                  */
    /* =================================================== */

    function test_setMultiVault_successful() external {
        address newMultiVault = makeAddr("newMultiVault");

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.MultiVaultSet(newMultiVault);

        resetPrank(users.admin);
        periphery.setMultiVault(newMultiVault);

        assertEq(address(periphery.multiVault()), newMultiVault);
        assertEq(address(periphery.multiVaultCore()), newMultiVault);
    }

    function test_setMultiVault_revertsOnNonAdmin() external {
        address newMultiVault = makeAddr("newMultiVault");

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, periphery.DEFAULT_ADMIN_ROLE()
            )
        );
        periphery.setMultiVault(newMultiVault);
    }

    function test_setMultiVault_revertsOnZeroAddress() external {
        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        periphery.setMultiVault(address(0));
    }

    function testFuzz_setMultiVault(address newMultiVault) external {
        vm.assume(newMultiVault != address(0));

        resetPrank(users.admin);
        periphery.setMultiVault(newMultiVault);

        assertEq(address(periphery.multiVault()), newMultiVault);
        assertEq(address(periphery.multiVaultCore()), newMultiVault);
    }

    /* =================================================== */
    /*              CREATE ATOMS FOR TESTS                 */
    /* =================================================== */

    function test_createAtomsFor_singleAtom() external {
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked("test atom");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 aliceBalanceBefore = users.alice.balance;

        bytes32 expectedAtomId = calculateAtomId(atomData[0]);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedBy(users.alice, users.bob, expectedAtomId, atomData[0]);

        resetPrank(users.alice);
        bytes32[] memory atomIds = periphery.createAtomsFor{ value: atomCost }(atomData, users.bob);

        assertEq(atomIds.length, 1);
        assertEq(atomIds[0], expectedAtomId);
        assertEq(users.alice.balance, aliceBalanceBefore - atomCost);
    }

    function test_createAtomsFor_multipleAtoms() external {
        bytes[] memory atomData = new bytes[](3);
        atomData[0] = abi.encodePacked("atom 1");
        atomData[1] = abi.encodePacked("atom 2");
        atomData[2] = abi.encodePacked("atom 3");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 totalCost = atomCost * 3;

        resetPrank(users.alice);
        bytes32[] memory atomIds = periphery.createAtomsFor{ value: totalCost }(atomData, users.bob);

        assertEq(atomIds.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(atomIds[i], calculateAtomId(atomData[i]));
        }
    }

    function test_createAtomsFor_revertsOnZeroCreator() external {
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked("test atom");

        uint256 atomCost = protocol.multiVault.getAtomCost();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        periphery.createAtomsFor{ value: atomCost }(atomData, address(0));
    }

    function test_createAtomsFor_revertsOnZeroLengthArray() external {
        bytes[] memory atomData = new bytes[](0);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_ZeroLengthArray.selector));
        periphery.createAtomsFor{ value: 1 ether }(atomData, users.bob);
    }

    function test_createAtomsFor_revertsOnInsufficientMsgValue() external {
        bytes[] memory atomData = new bytes[](2);
        atomData[0] = abi.encodePacked("atom 1");
        atomData[1] = abi.encodePacked("atom 2");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 requiredValue = atomCost * 2;
        uint256 insufficientValue = atomCost + (atomCost / 2);

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultPeriphery.MultiVaultPeriphery_InsufficientMsgValue.selector, requiredValue, insufficientValue
            )
        );
        periphery.createAtomsFor{ value: insufficientValue }(atomData, users.bob);
    }

    function test_createAtomsFor_refundsExcessValue() external {
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked("test atom");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 excessAmount = 1 ether;
        uint256 totalSent = atomCost + excessAmount;
        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createAtomsFor{ value: totalSent }(atomData, users.bob);

        assertEq(users.alice.balance, aliceBalanceBefore - atomCost);
    }

    function test_createAtomsFor_revertsOnRefundFailure() external {
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked("test atom");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 excessAmount = 1 ether;
        uint256 totalSent = atomCost + excessAmount;

        resetPrank(address(refundFailureMock));
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_RefundFailed.selector));
        periphery.createAtomsFor{ value: totalSent }(atomData, users.bob);
    }

    function test_createAtomsFor_emitsEventsForAllAtoms() external {
        bytes[] memory atomData = new bytes[](2);
        atomData[0] = abi.encodePacked("atom 1");
        atomData[1] = abi.encodePacked("atom 2");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 totalCost = atomCost * 2;

        bytes32 expectedAtomId0 = calculateAtomId(atomData[0]);
        bytes32 expectedAtomId1 = calculateAtomId(atomData[1]);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedBy(users.alice, users.bob, expectedAtomId0, atomData[0]);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedBy(users.alice, users.bob, expectedAtomId1, atomData[1]);

        resetPrank(users.alice);
        periphery.createAtomsFor{ value: totalCost }(atomData, users.bob);
    }

    function testFuzz_createAtomsFor(uint8 atomCount, uint256 excessValue) external {
        atomCount = uint8(bound(atomCount, 1, 20));
        excessValue = bound(excessValue, 0, 10 ether);

        bytes[] memory atomData = new bytes[](atomCount);
        for (uint256 i = 0; i < atomCount; i++) {
            atomData[i] = abi.encodePacked("atom ", i);
        }

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 requiredValue = atomCost * atomCount;
        uint256 totalValue = requiredValue + excessValue;

        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        bytes32[] memory atomIds = periphery.createAtomsFor{ value: totalValue }(atomData, users.bob);

        assertEq(atomIds.length, atomCount);
        assertEq(users.alice.balance, aliceBalanceBefore - requiredValue);
    }

    /* =================================================== */
    /*             CREATE TRIPLES FOR TESTS                */
    /* =================================================== */

    function test_createTriplesFor_singleTriple() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 aliceBalanceBefore = users.alice.balance;

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.TripleCreatedBy(users.alice, users.bob, bytes32(0), subjectId, predicateId, objectId);

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            periphery.createTriplesFor{ value: tripleCost }(subjects, predicates, objects, users.bob);

        assertEq(tripleIds.length, 1);
        assertEq(users.alice.balance, aliceBalanceBefore - tripleCost);
    }

    function test_createTriplesFor_multipleTriples() external {
        bytes32[] memory subjects = new bytes32[](3);
        bytes32[] memory predicates = new bytes32[](3);
        bytes32[] memory objects = new bytes32[](3);

        for (uint256 i = 0; i < 3; i++) {
            subjects[i] = createSimpleAtom(string(abi.encodePacked("subject", i)), getAtomCreationCost(), users.alice);
            predicates[i] =
                createSimpleAtom(string(abi.encodePacked("predicate", i)), getAtomCreationCost(), users.alice);
            objects[i] = createSimpleAtom(string(abi.encodePacked("object", i)), getAtomCreationCost(), users.alice);
        }

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = tripleCost * 3;

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            periphery.createTriplesFor{ value: totalCost }(subjects, predicates, objects, users.bob);

        assertEq(tripleIds.length, 3);
    }

    function test_createTriplesFor_revertsOnZeroCreator() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;

        uint256 tripleCost = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        periphery.createTriplesFor{ value: tripleCost }(subjects, predicates, objects, address(0));
    }

    function test_createTriplesFor_revertsOnZeroLengthArray() external {
        bytes32[] memory subjects = new bytes32[](0);
        bytes32[] memory predicates = new bytes32[](0);
        bytes32[] memory objects = new bytes32[](0);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_ZeroLengthArray.selector));
        periphery.createTriplesFor{ value: 1 ether }(subjects, predicates, objects, users.bob);
    }

    function test_createTriplesFor_revertsOnArrayLengthMismatchPredicates() external {
        bytes32[] memory subjects = new bytes32[](2);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](2);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_ArrayLengthMismatch.selector));
        periphery.createTriplesFor{ value: 1 ether }(subjects, predicates, objects, users.bob);
    }

    function test_createTriplesFor_revertsOnArrayLengthMismatchObjects() external {
        bytes32[] memory subjects = new bytes32[](2);
        bytes32[] memory predicates = new bytes32[](2);
        bytes32[] memory objects = new bytes32[](1);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_ArrayLengthMismatch.selector));
        periphery.createTriplesFor{ value: 1 ether }(subjects, predicates, objects, users.bob);
    }

    function test_createTriplesFor_revertsOnInsufficientMsgValue() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](2);
        bytes32[] memory predicates = new bytes32[](2);
        bytes32[] memory objects = new bytes32[](2);

        subjects[0] = subjectId;
        subjects[1] = subjectId;
        predicates[0] = predicateId;
        predicates[1] = predicateId;
        objects[0] = objectId;
        objects[1] = objectId;

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 requiredValue = tripleCost * 2;
        uint256 insufficientValue = tripleCost + (tripleCost / 2);

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultPeriphery.MultiVaultPeriphery_InsufficientMsgValue.selector, requiredValue, insufficientValue
            )
        );
        periphery.createTriplesFor{ value: insufficientValue }(subjects, predicates, objects, users.bob);
    }

    function test_createTriplesFor_refundsExcessValue() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 excessAmount = 1 ether;
        uint256 totalSent = tripleCost + excessAmount;
        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createTriplesFor{ value: totalSent }(subjects, predicates, objects, users.bob);

        assertEq(users.alice.balance, aliceBalanceBefore - tripleCost);
    }

    function test_createTriplesFor_revertsOnRefundFailure() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 excessAmount = 1 ether;
        uint256 totalSent = tripleCost + excessAmount;

        resetPrank(address(refundFailureMock));
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_RefundFailed.selector));
        periphery.createTriplesFor{ value: totalSent }(subjects, predicates, objects, users.bob);
    }

    function test_createTriplesFor_emitsEventsForAllTriples() external {
        bytes32[] memory subjects = new bytes32[](2);
        bytes32[] memory predicates = new bytes32[](2);
        bytes32[] memory objects = new bytes32[](2);

        for (uint256 i = 0; i < 2; i++) {
            subjects[i] = createSimpleAtom(string(abi.encodePacked("subject", i)), getAtomCreationCost(), users.alice);
            predicates[i] =
                createSimpleAtom(string(abi.encodePacked("predicate", i)), getAtomCreationCost(), users.alice);
            objects[i] = createSimpleAtom(string(abi.encodePacked("object", i)), getAtomCreationCost(), users.alice);
        }

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = tripleCost * 2;

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            periphery.createTriplesFor{ value: totalCost }(subjects, predicates, objects, users.bob);

        assertEq(tripleIds.length, 2);
    }

    function testFuzz_createTriplesFor(uint8 tripleCount, uint256 excessValue) external {
        tripleCount = uint8(bound(tripleCount, 1, 10));
        excessValue = bound(excessValue, 0, 10 ether);

        bytes32[] memory subjects = new bytes32[](tripleCount);
        bytes32[] memory predicates = new bytes32[](tripleCount);
        bytes32[] memory objects = new bytes32[](tripleCount);

        for (uint256 i = 0; i < tripleCount; i++) {
            subjects[i] = createSimpleAtom(string(abi.encodePacked("subject", i)), getAtomCreationCost(), users.alice);
            predicates[i] =
                createSimpleAtom(string(abi.encodePacked("predicate", i)), getAtomCreationCost(), users.alice);
            objects[i] = createSimpleAtom(string(abi.encodePacked("object", i)), getAtomCreationCost(), users.alice);
        }

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 requiredValue = tripleCost * tripleCount;
        uint256 totalValue = requiredValue + excessValue;

        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            periphery.createTriplesFor{ value: totalValue }(subjects, predicates, objects, users.bob);

        assertEq(tripleIds.length, tripleCount);
        assertEq(users.alice.balance, aliceBalanceBefore - requiredValue);
    }

    /* =================================================== */
    /*      BOOTSTRAP COUNTER TRIPLE VAULT TESTS           */
    /* =================================================== */

    function test_bootstrapCounterTripleVaultAndDepositFor_successful() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        bytes32 counterTripleId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.CounterTripleVaultBootstrappedAndDeposited(
            users.alice, users.bob, tripleId, counterTripleId, curveId, userAssets, 0
        );

        resetPrank(users.alice);
        uint256 userShares = periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );

        assertGt(userShares, 0);
        (uint256 bobAssets, uint256 bobShares) = protocol.multiVault.getVault(counterTripleId, curveId);
        assertGt(bobShares, 0);
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_revertsOnZeroReceiver() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, address(0)
        );
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_revertsOnZeroUserAssets() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 0;
        uint256 minSharesForUser = 0;

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidUserAssets.selector));
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_revertsOnNonTriple() external {
        bytes32 atomId = createSimpleAtom("atom", getAtomCreationCost(), users.alice);

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_OnlyTriplesAllowed.selector));
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            atomId, curveId, userAssets, minSharesForUser, users.bob
        );
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_revertsOnDefaultCurve() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 defaultCurveId = getDefaultCurveId();
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_DefaultCurveIdNotAllowed.selector)
        );
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, defaultCurveId, userAssets, minSharesForUser, users.bob
        );
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_revertsOnAlreadyInitialized() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 depositAmount = 1 ether;

        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, tripleId, curveId, 0);

        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultPeriphery.MultiVaultPeriphery_VaultAlreadyInitialized.selector, tripleId, curveId
            )
        );
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_revertsOnInsufficientMsgValue() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;
        uint256 insufficientValue = requiredValue - 1;

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultPeriphery.MultiVaultPeriphery_InsufficientMsgValue.selector, requiredValue, insufficientValue
            )
        );
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: insufficientValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_refundsExcessValue() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;
        uint256 excessAmount = 1 ether;
        uint256 totalSent = requiredValue + excessAmount;
        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: totalSent }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );

        assertEq(users.alice.balance, aliceBalanceBefore - requiredValue);
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_peripheryHoldsNoShares() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        bytes32 counterTripleId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        resetPrank(users.alice);
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );

        uint256 peripherySharesInPositiveVault = protocol.multiVault.getShares(address(periphery), tripleId, curveId);
        uint256 peripherySharesInCounterVault =
            protocol.multiVault.getShares(address(periphery), counterTripleId, curveId);

        assertEq(peripherySharesInPositiveVault, 0);
        assertEq(peripherySharesInCounterVault, 0);
    }

    // function testFuzz_bootstrapCounterTripleVaultAndDepositFor(uint256 userAssets, uint256 excessValue) external {
    //     userAssets = bound(userAssets, MIN_DEPOSIT, 100 ether);
    //     excessValue = bound(excessValue, 0, 10 ether);

    //     bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
    //     bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
    //     bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

    //     bytes32[] memory subjects = new bytes32[](1);
    //     bytes32[] memory predicates = new bytes32[](1);
    //     bytes32[] memory objects = new bytes32[](1);
    //     uint256[] memory assets = new uint256[](1);

    //     subjects[0] = subjectId;
    //     predicates[0] = predicateId;
    //     objects[0] = objectId;
    //     assets[0] = protocol.multiVault.getTripleCost();

    //     resetPrank(users.alice);
    //     bytes32[] memory tripleIds =
    //         protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
    //     bytes32 tripleId = tripleIds[0];

    //     uint256 curveId = 2;
    //     uint256 minSharesForUser = 0;

    //     setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

    //     uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
    //     uint256 requiredValue = minDeposit + userAssets;
    //     uint256 totalValue = requiredValue + excessValue;

    //     uint256 aliceBalanceBefore = users.alice.balance;

    //     resetPrank(users.alice);
    //     uint256 userShares = periphery.bootstrapCounterTripleVaultAndDepositFor{ value: totalValue }(
    //         tripleId, curveId, userAssets, minSharesForUser, users.bob
    //     );

    //     assertGt(userShares, 0);
    //     assertEq(users.alice.balance, aliceBalanceBefore - requiredValue);

    //     uint256 peripherySharesInPositiveVault = protocol.multiVault.getShares(address(periphery), tripleId,
    // curveId); assertEq(peripherySharesInPositiveVault, 0);
    // }

    /* =================================================== */
    /*              MULTICALL3 TESTS                       */
    /* =================================================== */

    function test_multicall_aggregate() external {
        bytes[] memory atomData = new bytes[](2);
        atomData[0] = abi.encodePacked("atom1");
        atomData[1] = abi.encodePacked("atom2");

        uint256 atomCost = protocol.multiVault.getAtomCost();

        Multicall3.Call[] memory calls = new Multicall3.Call[](1);
        calls[0] = Multicall3.Call({
            target: address(periphery),
            callData: abi.encodeWithSelector(periphery.createAtomsFor.selector, atomData, users.bob)
        });

        resetPrank(users.alice);
        (uint256 blockNumber, bytes[] memory returnData) = periphery.aggregate{ value: atomCost * 2 }(calls);

        assertEq(blockNumber, block.number);
        assertEq(returnData.length, 1);
    }

    function test_multicall_getBlockNumber() external view {
        uint256 blockNumber = periphery.getBlockNumber();
        assertEq(blockNumber, block.number);
    }

    function test_multicall_getBlockHash() external {
        vm.roll(100);
        bytes32 blockHash = periphery.getBlockHash(99);
        assertEq(blockHash, blockhash(99));
    }

    function test_multicall_getCurrentBlockTimestamp() external view {
        uint256 timestamp = periphery.getCurrentBlockTimestamp();
        assertEq(timestamp, block.timestamp);
    }

    function test_multicall_getEthBalance() external view {
        uint256 balance = periphery.getEthBalance(users.alice);
        assertEq(balance, users.alice.balance);
    }

    function test_multicall_getChainId() external view {
        uint256 chainId = periphery.getChainId();
        assertEq(chainId, block.chainid);
    }

    /* =================================================== */
    /*                 REENTRANCY TESTS                    */
    /* =================================================== */

    function test_createAtomsFor_reentrancyGuard() external {
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked("test atom");

        uint256 atomCost = protocol.multiVault.getAtomCost();

        resetPrank(users.alice);
        periphery.createAtomsFor{ value: atomCost }(atomData, users.bob);
    }

    function test_createTriplesFor_reentrancyGuard() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;

        uint256 tripleCost = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        periphery.createTriplesFor{ value: tripleCost }(subjects, predicates, objects, users.bob);
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_reentrancyGuard() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );
    }

    /* =================================================== */
    /*                   EDGE CASE TESTS                   */
    /* =================================================== */

    function test_createAtomsFor_exactValue() external {
        bytes[] memory atomData = new bytes[](3);
        atomData[0] = abi.encodePacked("atom1");
        atomData[1] = abi.encodePacked("atom2");
        atomData[2] = abi.encodePacked("atom3");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 exactValue = atomCost * 3;
        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createAtomsFor{ value: exactValue }(atomData, users.bob);

        assertEq(users.alice.balance, aliceBalanceBefore - exactValue);
    }

    function test_createTriplesFor_exactValue() external {
        bytes32[] memory subjects = new bytes32[](2);
        bytes32[] memory predicates = new bytes32[](2);
        bytes32[] memory objects = new bytes32[](2);

        for (uint256 i = 0; i < 2; i++) {
            subjects[i] = createSimpleAtom(string(abi.encodePacked("subject", i)), getAtomCreationCost(), users.alice);
            predicates[i] =
                createSimpleAtom(string(abi.encodePacked("predicate", i)), getAtomCreationCost(), users.alice);
            objects[i] = createSimpleAtom(string(abi.encodePacked("object", i)), getAtomCreationCost(), users.alice);
        }

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 exactValue = tripleCost * 2;
        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createTriplesFor{ value: exactValue }(subjects, predicates, objects, users.bob);

        assertEq(users.alice.balance, aliceBalanceBefore - exactValue);
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_exactValue() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1 ether;
        uint256 minSharesForUser = 0;

        setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 exactValue = minDeposit + userAssets;
        uint256 aliceBalanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.bootstrapCounterTripleVaultAndDepositFor{ value: exactValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );

        assertEq(users.alice.balance, aliceBalanceBefore - exactValue);
    }

    function test_createAtomsFor_largeArray() external {
        uint256 atomCount = 50;
        bytes[] memory atomData = new bytes[](atomCount);

        for (uint256 i = 0; i < atomCount; i++) {
            atomData[i] = abi.encodePacked("atom", i);
        }

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 totalCost = atomCost * atomCount;

        resetPrank(users.alice);
        bytes32[] memory atomIds = periphery.createAtomsFor{ value: totalCost }(atomData, users.bob);

        assertEq(atomIds.length, atomCount);
    }

    function test_bootstrapCounterTripleVaultAndDepositFor_minUserAssets() external {
        bytes32 subjectId = createSimpleAtom("subject", getAtomCreationCost(), users.alice);
        bytes32 predicateId = createSimpleAtom("predicate", getAtomCreationCost(), users.alice);
        bytes32 objectId = createSimpleAtom("object", getAtomCreationCost(), users.alice);

        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        assets[0] = protocol.multiVault.getTripleCost();

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: assets[0] }(subjects, predicates, objects, assets);
        bytes32 tripleId = tripleIds[0];

        uint256 curveId = 2;
        uint256 userAssets = 1;
        uint256 minSharesForUser = 0;

        setupApproval(users.bob, address(periphery), ApprovalTypes.DEPOSIT);

        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 requiredValue = minDeposit + userAssets;

        resetPrank(users.alice);
        uint256 userShares = periphery.bootstrapCounterTripleVaultAndDepositFor{ value: requiredValue }(
            tripleId, curveId, userAssets, minSharesForUser, users.bob
        );

        assertGt(userShares, 0);
    }

    function test_setMultiVault_multipleChanges() external {
        address newMultiVault1 = makeAddr("newMultiVault1");
        address newMultiVault2 = makeAddr("newMultiVault2");

        resetPrank(users.admin);
        periphery.setMultiVault(newMultiVault1);
        assertEq(address(periphery.multiVault()), newMultiVault1);

        periphery.setMultiVault(newMultiVault2);
        assertEq(address(periphery.multiVault()), newMultiVault2);
    }
}
