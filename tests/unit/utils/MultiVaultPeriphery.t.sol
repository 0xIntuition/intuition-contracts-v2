// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVaultPeriphery } from "src/utils/MultiVaultPeriphery.sol";
import { IMultiVaultPeriphery } from "src/interfaces/IMultiVaultPeriphery.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract RevertOnReceive {
    receive() external payable {
        revert("Cannot receive ETH");
    }
}

contract MultiVaultPeripheryTest is BaseTest {
    MultiVaultPeriphery public multiVaultPeripheryImpl;
    TransparentUpgradeableProxy public multiVaultPeripheryProxy;
    MultiVaultPeriphery public periphery;

    function setUp() public override {
        super.setUp();

        multiVaultPeripheryImpl = new MultiVaultPeriphery();
        multiVaultPeripheryProxy = new TransparentUpgradeableProxy(address(multiVaultPeripheryImpl), users.admin, "");
        periphery = MultiVaultPeriphery(address(multiVaultPeripheryProxy));
        periphery.initialize(users.admin, address(protocol.multiVault));
    }

    /* =================================================== */
    /*                  CONSTRUCTOR TESTS                  */
    /* =================================================== */

    function test_constructor_disablesInitializers() external {
        MultiVaultPeriphery newPeriphery = new MultiVaultPeriphery();

        vm.expectRevert();
        newPeriphery.initialize(users.admin, address(protocol.multiVault));
    }

    /* =================================================== */
    /*                  INITIALIZER TESTS                  */
    /* =================================================== */

    function test_initialize_successful() external {
        MultiVaultPeriphery newPeripheryImpl = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newPeripheryImpl), users.admin, "");
        MultiVaultPeriphery newPeriphery = MultiVaultPeriphery(address(newProxy));

        newPeriphery.initialize(users.admin, address(protocol.multiVault));

        assertEq(address(newPeriphery.multiVault()), address(protocol.multiVault));
        assertEq(address(newPeriphery.multiVaultCore()), address(protocol.multiVault));
        assertTrue(newPeriphery.hasRole(newPeriphery.DEFAULT_ADMIN_ROLE(), users.admin));
    }

    function test_initialize_emitsMultiVaultSetEvent() external {
        MultiVaultPeriphery newPeripheryImpl = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newPeripheryImpl), users.admin, "");
        MultiVaultPeriphery newPeriphery = MultiVaultPeriphery(address(newProxy));

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.MultiVaultSet(address(protocol.multiVault));
        newPeriphery.initialize(users.admin, address(protocol.multiVault));
    }

    function test_initialize_revertsWhenCalledTwice() external {
        vm.expectRevert();
        periphery.initialize(users.admin, address(protocol.multiVault));
    }

    function test_initialize_revertsOnZeroAddressMultiVault() external {
        MultiVaultPeriphery newPeripheryImpl = new MultiVaultPeriphery();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newPeripheryImpl), users.admin, "");
        MultiVaultPeriphery newPeriphery = MultiVaultPeriphery(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        newPeriphery.initialize(users.admin, address(0));
    }

    /* =================================================== */
    /*                 ADMIN FUNCTIONS TESTS               */
    /* =================================================== */

    function test_setMultiVault_successful() external {
        address newMultiVault = makeAddr("newMultiVault");

        resetPrank(users.admin);
        periphery.setMultiVault(newMultiVault);

        assertEq(address(periphery.multiVault()), newMultiVault);
        assertEq(address(periphery.multiVaultCore()), newMultiVault);
    }

    function test_setMultiVault_emitsMultiVaultSetEvent() external {
        address newMultiVault = makeAddr("newMultiVault");

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.MultiVaultSet(newMultiVault);

        resetPrank(users.admin);
        periphery.setMultiVault(newMultiVault);
    }

    function test_setMultiVault_revertsOnZeroAddress() external {
        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidAddress.selector));
        periphery.setMultiVault(address(0));
    }

    function test_setMultiVault_revertsWhenCalledByNonAdmin() external {
        address newMultiVault = makeAddr("newMultiVault");

        resetPrank(users.alice);
        vm.expectRevert();
        periphery.setMultiVault(newMultiVault);
    }

    function testFuzz_setMultiVault_revertsWhenCalledByNonAdmin(address nonAdmin) external {
        vm.assume(nonAdmin != users.admin);
        vm.assume(nonAdmin != address(0));

        address newMultiVault = makeAddr("newMultiVault");

        resetPrank(nonAdmin);
        vm.expectRevert();
        periphery.setMultiVault(newMultiVault);
    }

    /* =================================================== */
    /*          CREATE TRIPLE WITH ATOMS TESTS             */
    /* =================================================== */

    function test_createTripleWithAtoms_allNewAtoms() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId = periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);

        assertEq(tripleId, expectedTripleId);
        assertTrue(protocol.multiVault.isAtom(expectedSubjectId));
        assertTrue(protocol.multiVault.isAtom(expectedPredicateId));
        assertTrue(protocol.multiVault.isAtom(expectedObjectId));
        assertTrue(protocol.multiVault.isTriple(tripleId));
    }

    function test_createTripleWithAtoms_someExistingAtoms() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();

        createAtomWithDeposit(subjectData, atomCost, users.alice);
        createAtomWithDeposit(predicateData, atomCost, users.alice);

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = atomCost + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId = periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);

        assertEq(tripleId, expectedTripleId);
        assertTrue(protocol.multiVault.isAtom(expectedObjectId));
        assertTrue(protocol.multiVault.isTriple(tripleId));
    }

    function test_createTripleWithAtoms_allExistingAtoms() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();

        createAtomWithDeposit(subjectData, atomCost, users.alice);
        createAtomWithDeposit(predicateData, atomCost, users.alice);
        createAtomWithDeposit(objectData, atomCost, users.alice);

        uint256 tripleCost = protocol.multiVault.getTripleCost();

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId = periphery.createTripleWithAtoms{ value: tripleCost }(subjectData, predicateData, objectData);

        assertEq(tripleId, expectedTripleId);
        assertTrue(protocol.multiVault.isTriple(tripleId));
    }

    function test_createTripleWithAtoms_emitsTripleCreatedForEvent() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.TripleCreatedFor(
            users.alice, users.alice, expectedTripleId, expectedSubjectId, expectedPredicateId, expectedObjectId
        );

        resetPrank(users.alice);
        periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);
    }

    function test_createTripleWithAtoms_emitsAtomCreatedForEvents() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedFor(users.alice, users.alice, expectedSubjectId, subjectData);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedFor(users.alice, users.alice, expectedPredicateId, predicateData);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedFor(users.alice, users.alice, expectedObjectId, objectData);

        resetPrank(users.alice);
        periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);
    }

    function test_createTripleWithAtoms_refundsExcessValue() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;
        uint256 excessAmount = 1 ether;
        uint256 sentAmount = totalCost + excessAmount;

        uint256 balanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createTripleWithAtoms{ value: sentAmount }(subjectData, predicateData, objectData);

        uint256 balanceAfter = users.alice.balance;
        assertEq(balanceBefore - balanceAfter, totalCost);
    }

    function test_createTripleWithAtoms_revertsOnInsufficientMsgValue() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;
        uint256 insufficientAmount = totalCost - 1;

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultPeriphery.MultiVaultPeriphery_InsufficientMsgValue.selector, totalCost, insufficientAmount
            )
        );
        periphery.createTripleWithAtoms{ value: insufficientAmount }(subjectData, predicateData, objectData);
    }

    // function testFuzz_createTripleWithAtoms_allNewAtoms(
    //     bytes calldata subjectData,
    //     bytes calldata predicateData,
    //     bytes calldata objectData
    // )
    //     external
    // {
    //     vm.assume(subjectData.length > 0 && subjectData.length <= ATOM_DATA_MAX_LENGTH);
    //     vm.assume(predicateData.length > 0 && predicateData.length <= ATOM_DATA_MAX_LENGTH);
    //     vm.assume(objectData.length > 0 && objectData.length <= ATOM_DATA_MAX_LENGTH);

    //     bytes32 subjectId = protocol.multiVault.calculateAtomId(subjectData);
    //     bytes32 predicateId = protocol.multiVault.calculateAtomId(predicateData);
    //     bytes32 objectId = protocol.multiVault.calculateAtomId(objectData);

    //     vm.assume(!protocol.multiVault.isAtom(subjectId));
    //     vm.assume(!protocol.multiVault.isAtom(predicateId));
    //     vm.assume(!protocol.multiVault.isAtom(objectId));

    //     uint256 atomCost = protocol.multiVault.getAtomCost();
    //     uint256 tripleCost = protocol.multiVault.getTripleCost();
    //     uint256 totalCost = (atomCost * 3) + tripleCost;

    //     bytes32 expectedTripleId = protocol.multiVault.calculateTripleId(subjectId, predicateId, objectId);

    //     resetPrank(users.alice);
    //     bytes32 tripleId = periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);

    //     assertEq(tripleId, expectedTripleId);
    //     assertTrue(protocol.multiVault.isAtom(subjectId));
    //     assertTrue(protocol.multiVault.isAtom(predicateId));
    //     assertTrue(protocol.multiVault.isAtom(objectId));
    //     assertTrue(protocol.multiVault.isTriple(tripleId));
    // }

    function testFuzz_createTripleWithAtoms_refundsExcessValue(uint256 excessAmount) external {
        excessAmount = bound(excessAmount, 0, 100 ether);

        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;
        uint256 sentAmount = totalCost + excessAmount;

        uint256 balanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createTripleWithAtoms{ value: sentAmount }(subjectData, predicateData, objectData);

        uint256 balanceAfter = users.alice.balance;
        assertEq(balanceBefore - balanceAfter, totalCost);
    }

    /* =================================================== */
    /*       CREATE TRIPLE WITH ATOMS FOR TESTS            */
    /* =================================================== */

    function test_createTripleWithAtomsFor_successful() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId =
            periphery.createTripleWithAtomsFor{ value: totalCost }(subjectData, predicateData, objectData, users.bob);

        assertEq(tripleId, expectedTripleId);
        assertTrue(protocol.multiVault.isAtom(expectedSubjectId));
        assertTrue(protocol.multiVault.isAtom(expectedPredicateId));
        assertTrue(protocol.multiVault.isAtom(expectedObjectId));
        assertTrue(protocol.multiVault.isTriple(tripleId));
    }

    function test_createTripleWithAtomsFor_emitsEventsWithCorrectCreator() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedFor(users.alice, users.bob, expectedSubjectId, subjectData);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedFor(users.alice, users.bob, expectedPredicateId, predicateData);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.AtomCreatedFor(users.alice, users.bob, expectedObjectId, objectData);

        vm.expectEmit(true, true, true, true);
        emit IMultiVaultPeriphery.TripleCreatedFor(
            users.alice, users.bob, expectedTripleId, expectedSubjectId, expectedPredicateId, expectedObjectId
        );

        resetPrank(users.alice);
        periphery.createTripleWithAtomsFor{ value: totalCost }(subjectData, predicateData, objectData, users.bob);
    }

    function test_createTripleWithAtomsFor_revertsOnZeroAddressCreator() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiVaultPeriphery.MultiVaultPeriphery_InvalidCreator.selector));
        periphery.createTripleWithAtomsFor{ value: totalCost }(subjectData, predicateData, objectData, address(0));
    }

    function test_createTripleWithAtomsFor_withExistingAtomsRefundsCorrectly() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();

        createAtomWithDeposit(subjectData, atomCost, users.alice);

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 2) + tripleCost;

        uint256 balanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createTripleWithAtomsFor{ value: totalCost }(subjectData, predicateData, objectData, users.bob);

        uint256 balanceAfter = users.alice.balance;
        assertEq(balanceBefore - balanceAfter, totalCost);
    }

    // function testFuzz_createTripleWithAtomsFor_successful(address creator) external {
    //     vm.assume(creator != address(0));
    //     _excludeReservedAddresses(creator);

    //     bytes memory subjectData = abi.encodePacked("subject");
    //     bytes memory predicateData = abi.encodePacked("predicate");
    //     bytes memory objectData = abi.encodePacked("object");

    //     uint256 atomCost = protocol.multiVault.getAtomCost();
    //     uint256 tripleCost = protocol.multiVault.getTripleCost();
    //     uint256 totalCost = (atomCost * 3) + tripleCost;

    //     bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
    //     bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
    //     bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
    //     bytes32 expectedTripleId =
    //         protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

    //     resetPrank(users.alice);
    //     bytes32 tripleId =
    //         periphery.createTripleWithAtomsFor{ value: totalCost }(subjectData, predicateData, objectData, creator);

    //     assertEq(tripleId, expectedTripleId);
    //     assertTrue(protocol.multiVault.isTriple(tripleId));
    // }

    /* =================================================== */
    /*              REFUND MECHANISM TESTS                 */
    /* =================================================== */

    function test_refund_failsGracefullyWithRevertingReceiver() external {
        vm.stopPrank();
        RevertOnReceive revertingContract = new RevertOnReceive();

        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;
        uint256 excessAmount = 1 ether;

        vm.deal(address(revertingContract), totalCost + excessAmount);

        vm.prank(address(revertingContract));
        vm.expectRevert("MultiVaultPeriphery: Refund failed");
        periphery.createTripleWithAtoms{ value: totalCost + excessAmount }(subjectData, predicateData, objectData);
    }

    function test_refund_noRefundWhenExactAmountSent() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        uint256 balanceBefore = users.alice.balance;

        resetPrank(users.alice);
        periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);

        uint256 balanceAfter = users.alice.balance;
        assertEq(balanceBefore - balanceAfter, totalCost);
    }

    /* =================================================== */
    /*                    EDGE CASES                       */
    /* =================================================== */

    function test_createTripleWithAtoms_withMaxLengthAtomData() external {
        bytes memory subjectData = new bytes(ATOM_DATA_MAX_LENGTH);
        bytes memory predicateData = new bytes(ATOM_DATA_MAX_LENGTH);
        bytes memory objectData = new bytes(ATOM_DATA_MAX_LENGTH);

        for (uint256 i = 0; i < ATOM_DATA_MAX_LENGTH; i++) {
            subjectData[i] = bytes1(uint8(i % 256));
            predicateData[i] = bytes1(uint8((i + 1) % 256));
            objectData[i] = bytes1(uint8((i + 2) % 256));
        }

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId = periphery.createTripleWithAtoms{ value: totalCost }(subjectData, predicateData, objectData);

        assertEq(tripleId, expectedTripleId);
        assertTrue(protocol.multiVault.isTriple(tripleId));
    }

    function test_createTripleWithAtoms_withIdenticalAtomData() external {
        bytes memory atomData = abi.encodePacked("identical");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();T
        uint256 totalCost = atomCost + tripleCost;

        bytes32 atomId = protocol.multiVault.calculateAtomId(atomData);
        bytes32 expectedTripleId = protocol.multiVault.calculateTripleId(atomId, atomId, atomId);

        resetPrank(users.alice);
        bytes32 tripleId = periphery.createTripleWithAtoms{ value: totalCost }(atomData, atomData, atomData);

        assertEq(tripleId, expectedTripleId);
        assertTrue(protocol.multiVault.isAtom(atomId));
        assertTrue(protocol.multiVault.isTriple(tripleId));
    }

    function test_createTripleWithAtoms_multipleCallsWithSameData() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCostFirst = (atomCost * 3) + tripleCost;
        uint256 totalCostSecond = tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId1 =
            periphery.createTripleWithAtoms{ value: totalCostFirst }(subjectData, predicateData, objectData);

        vm.expectRevert();
        periphery.createTripleWithAtoms{ value: totalCostSecond }(subjectData, predicateData, objectData);

        assertEq(tripleId1, expectedTripleId);
    }

    function test_createTripleWithAtomsFor_multipleUsersCreatingForSameCreator() external {
        bytes memory subjectData = abi.encodePacked("subject");
        bytes memory predicateData = abi.encodePacked("predicate");
        bytes memory objectData = abi.encodePacked("object");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 totalCost = (atomCost * 3) + tripleCost;

        bytes32 expectedSubjectId = protocol.multiVault.calculateAtomId(subjectData);
        bytes32 expectedPredicateId = protocol.multiVault.calculateAtomId(predicateData);
        bytes32 expectedObjectId = protocol.multiVault.calculateAtomId(objectData);
        bytes32 expectedTripleId =
            protocol.multiVault.calculateTripleId(expectedSubjectId, expectedPredicateId, expectedObjectId);

        resetPrank(users.alice);
        bytes32 tripleId = periphery.createTripleWithAtomsFor{ value: totalCost }(
            subjectData, predicateData, objectData, users.charlie
        );

        assertEq(tripleId, expectedTripleId);

        bytes memory subject2Data = abi.encodePacked("subject2");
        bytes memory predicate2Data = abi.encodePacked("predicate2");
        bytes memory object2Data = abi.encodePacked("object2");

        bytes32 expectedSubject2Id = protocol.multiVault.calculateAtomId(subject2Data);
        bytes32 expectedPredicate2Id = protocol.multiVault.calculateAtomId(predicate2Data);
        bytes32 expectedObject2Id = protocol.multiVault.calculateAtomId(object2Data);
        bytes32 expectedTriple2Id =
            protocol.multiVault.calculateTripleId(expectedSubject2Id, expectedPredicate2Id, expectedObject2Id);

        resetPrank(users.bob);
        bytes32 tripleId2 = periphery.createTripleWithAtomsFor{ value: totalCost }(
            subject2Data, predicate2Data, object2Data, users.charlie
        );

        assertEq(tripleId2, expectedTriple2Id);
        assertTrue(tripleId != tripleId2);
    }

    /* =================================================== */
    /*                  STATE VERIFICATION                 */
    /* =================================================== */

    function test_stateVerification_multiVaultAddressSetCorrectly() external view {
        assertEq(address(periphery.multiVault()), address(protocol.multiVault));
        assertEq(address(periphery.multiVaultCore()), address(protocol.multiVault));
    }

    function test_stateVerification_adminRoleGrantedCorrectly() external view {
        assertTrue(periphery.hasRole(periphery.DEFAULT_ADMIN_ROLE(), users.admin));
    }

    function test_stateVerification_nonAdminDoesNotHaveRole() external view {
        assertFalse(periphery.hasRole(periphery.DEFAULT_ADMIN_ROLE(), users.alice));
        assertFalse(periphery.hasRole(periphery.DEFAULT_ADMIN_ROLE(), users.bob));
    }
}
