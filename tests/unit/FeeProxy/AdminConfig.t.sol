// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy, FeeConfig } from "src/interfaces/IFeeProxy.sol";

contract AdminConfigTest is FeeProxyBaseTest {
    function test_setMaxFeeBps_Success() external {
        uint256 previous = feeProxy.maxFeeBps();
        uint256 next = 5000;

        vm.prank(feeProxyAdmin);
        vm.expectEmit(false, false, false, true, address(feeProxy));
        emit IFeeProxy.MaxFeeBpsUpdated(previous, next);
        feeProxy.setMaxFeeBps(next);

        assertEq(feeProxy.maxFeeBps(), next);
    }

    function test_setMaxFeeBps_AcceptsBpsDivisor() external {
        vm.prank(feeProxyAdmin);
        feeProxy.setMaxFeeBps(10_000);

        assertEq(feeProxy.maxFeeBps(), 10_000);
    }

    function test_setMaxFeeBps_RevertWhen_AboveBpsDivisor() external {
        vm.prank(feeProxyAdmin);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_MaxFeeBpsOutOfRange.selector, 10_001));
        feeProxy.setMaxFeeBps(10_001);
    }

    function test_setMaxFixedFee_Success() external {
        uint256 previous = feeProxy.maxFixedFee();
        uint256 next = 5 ether;

        vm.prank(feeProxyAdmin);
        vm.expectEmit(false, false, false, true, address(feeProxy));
        emit IFeeProxy.MaxFixedFeeUpdated(previous, next);
        feeProxy.setMaxFixedFee(next);

        assertEq(feeProxy.maxFixedFee(), next);
    }

    function test_setMaxFixedFee_AcceptsZero() external {
        vm.prank(feeProxyAdmin);
        feeProxy.setMaxFixedFee(0);

        assertEq(feeProxy.maxFixedFee(), 0);
    }

    function test_setRegistrationFee_Success() external {
        uint256 previous = feeProxy.registrationFee();
        uint256 next = 1 ether;

        vm.prank(feeProxyAdmin);
        vm.expectEmit(false, false, false, true, address(feeProxy));
        emit IFeeProxy.RegistrationFeeUpdated(previous, next);
        feeProxy.setRegistrationFee(next);

        assertEq(feeProxy.registrationFee(), next);
    }

    function test_setRegistrationFee_AcceptsZero() external {
        vm.prank(feeProxyAdmin);
        feeProxy.setRegistrationFee(0);

        assertEq(feeProxy.registrationFee(), 0);
    }

    function test_capUpdates_DoNotMutateExistingRowStorage() external {
        _registerSampleAffiliate();

        // Drop caps below the registered values.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFeeBps(SAMPLE_DEPOSIT_BPS - 1);
        feeProxy.setMaxFixedFee(SAMPLE_CREATION_FIXED_FEE - 1);
        vm.stopPrank();

        // The row itself is not rewritten by the cap drop; only routing-time
        // enforcement blocks it from being used until the affiliate updates
        // fees down via {updateAffiliateFees}.
        assertEq(feeProxy.affiliateConfig(affiliate).fees.depositBps, SAMPLE_DEPOSIT_BPS, "row depositBps preserved");
        assertEq(
            feeProxy.affiliateConfig(affiliate).fees.creationFixedFee,
            SAMPLE_CREATION_FIXED_FEE,
            "row creationFixedFee preserved"
        );
    }

    function test_capDrop_BlocksDepositSideRoutingForOverCapAffiliate() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("cap-drop-deposit-blocks", users.alice);

        // Drop the bps cap below the registered deposit bps.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFeeBps(SAMPLE_DEPOSIT_BPS - 1);
        vm.stopPrank();

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_BpsExceedsCap.selector, SAMPLE_DEPOSIT_BPS, SAMPLE_DEPOSIT_BPS - 1
            )
        );
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_capDrop_BlocksCreationSideRoutingForOverCapAffiliate() external {
        _registerSampleAffiliate();

        // Drop the fixed-fee cap below the registered creation fixed fee.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFixedFee(SAMPLE_CREATION_FIXED_FEE - 1);
        vm.stopPrank();

        bytes[] memory atomDatas = _toBytesArray("cap-drop-creation-blocks");
        uint256[] memory assets = _toUintArray(1 ether);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCap.selector, SAMPLE_CREATION_FIXED_FEE, SAMPLE_CREATION_FIXED_FEE - 1
            )
        );
        feeProxy.createAtomsVia{ value: 1 ether }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_capDrop_DepositSideDoesNotBlockCreationRouting() external {
        // Sanity: a deposit-side cap drop does not block a creation route as
        // long as the creation-side fees still fit the (untouched) creation
        // cap. The two sides are checked independently at execution time.
        _registerSampleAffiliate();

        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFeeBps(SAMPLE_DEPOSIT_BPS - 1); // tightens against deposit bps only
        // Lift the fixed-fee cap so the creation fixed fee stays under the cap
        // even after the bps cap change.
        feeProxy.setMaxFixedFee(INITIAL_MAX_FIXED_FEE);
        vm.stopPrank();

        // Creation-side bps (SAMPLE_CREATION_BPS) still exceeds the new bps
        // cap, so the asymmetry is only visible when the creation bps is
        // independently under the cap. Re-register a zero-creation-bps
        // affiliate to isolate the side check.
        address payable creationOnly = payable(makeAddr("creationOnlyAffiliate"));
        address payable creationOnlyRecipient = payable(makeAddr("creationOnlyRecipient"));
        FeeConfig memory creationOnlyFees =
            FeeConfig({ depositBps: 0, creationBps: 0, depositFixedFee: 0, creationFixedFee: 0 });
        vm.deal(creationOnly, INITIAL_REGISTRATION_FEE);
        vm.startPrank(creationOnly);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(creationOnlyFees, creationOnlyRecipient);
        vm.stopPrank();

        bytes[] memory atomDatas = _toBytesArray("cap-drop-creation-still-works");
        uint256[] memory assets = _toUintArray(1 ether);
        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        feeProxy.createAtomsVia{ value: 1 ether }(creationOnly, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }
}
