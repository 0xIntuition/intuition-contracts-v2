// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { console } from "forge-std/src/console.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract CounterStakeGuardTest is BaseTest {
    bytes32 private tripleId;
    bytes32 private counterTripleId;

    function setUp() public override {
        super.setUp();

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        if (minDeposit == 0) minDeposit = 1;

        (bytes32 _tripleId,) =
            createTripleWithAtoms("S:Local", "P:Local", "O:Local", atomCost, tripleCost + minDeposit, users.alice);
        tripleId = _tripleId;
        counterTripleId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        console.log("Local tripleId:", vm.toString(tripleId));
        console.log("Local counterId:", vm.toString(counterTripleId));
    }

    function test_MappingIsBidirectional() public view {
        bytes32 derivedCounterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);
        bytes32 derivedTripleId = protocol.multiVault.getTripleIdFromCounterId(counterTripleId);

        assertEq(derivedCounterId, counterTripleId, "counterId mismatch");
        assertEq(derivedTripleId, tripleId, "tripleId mismatch from counterId");
        assertTrue(protocol.multiVault.isTriple(tripleId), "tripleId must be a triple");
        assertTrue(protocol.multiVault.isCounterTriple(counterTripleId), "counterTripleId must be counter");
    }

    function test_DepositOppositeSideSameCurve_RevertsHasCounterStake() public {
        uint256 defaultCurveId = getDefaultCurveId();

        uint256 assets = protocol.multiVault.getGeneralConfig().minDeposit;
        if (assets == 0) assets = 1;
        vm.deal(users.alice, assets);

        uint256 preShares = protocol.multiVault.getShares(users.alice, tripleId, defaultCurveId);
        console.log("preShares on positive triple:", preShares);
        assertGt(preShares, 0, "expected positive-side shares for Alice after triple creation");

        vm.expectRevert(MultiVault.MultiVault_HasCounterStake.selector);
        makeDeposit(users.alice, users.alice, counterTripleId, defaultCurveId, assets, 0);
    }

    function test_CrossCurveDepositsAllowed() public {
        (address registryAddr, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        IBondingCurveRegistry reg = IBondingCurveRegistry(registryAddr);

        uint256 otherCurveId;
        uint256 count = reg.count();
        for (uint256 i = 1; i <= count; i++) {
            if (i != defaultCurveId && reg.curveAddresses(i) != address(0)) {
                otherCurveId = i;
                break;
            }
        }
        vm.assume(otherCurveId != 0);

        uint256 assets = protocol.multiVault.getGeneralConfig().minDeposit;
        if (assets == 0) assets = 1;

        // 1) Bob initializes the non-default curve on the POSITIVE side.
        vm.deal(users.bob, assets);
        uint256 sharesPos = makeDeposit(users.bob, users.bob, tripleId, otherCurveId, assets, 0);
        assertGt(sharesPos, 0, "positive deposit should mint shares on other curve");

        // 2) Now Alice can deposit to the COUNTER side on that curve (she has no positive shares on this curve).
        vm.deal(users.alice, assets);
        uint256 sharesNeg = makeDeposit(users.alice, users.alice, counterTripleId, otherCurveId, assets, 0);
        assertGt(sharesNeg, 0, "cross-curve counter deposit should mint shares");
    }

    function test_DepositBatchBothSidesSameCurve_RevertsHasCounterStake() public {
        uint256 defaultCurveId = getDefaultCurveId();

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = tripleId;
        termIds[1] = counterTripleId;

        uint256[] memory curveIds = new uint256[](2);
        curveIds[0] = defaultCurveId;
        curveIds[1] = defaultCurveId;

        uint256 assetsPerLeg = protocol.multiVault.getGeneralConfig().minDeposit;
        if (assetsPerLeg == 0) assetsPerLeg = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = assetsPerLeg;
        amounts[1] = assetsPerLeg;

        uint256[] memory minShares = new uint256[](2);

        vm.deal(users.alice, amounts[0] + amounts[1]);

        vm.expectRevert(MultiVault.MultiVault_HasCounterStake.selector);
        makeDepositBatch(users.alice, users.alice, termIds, curveIds, amounts, minShares);
    }
}
