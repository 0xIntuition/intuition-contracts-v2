// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { AffiliateConfig, FeeConfig, FeeGuard } from "src/interfaces/IFeeProxy.sol";
import { FeeProxy } from "src/periphery/FeeProxy.sol";

/// @notice Refund-flow mock: rejects every native ETH transfer in its
///         `receive`, forcing the {FeeProxy} push leg to fail and the
///         pull-fallback ledger to credit the configured `caller`.
contract RevertingReceiverMock {
    address public immutable feeProxy;
    address public immutable multiVault;

    constructor(address feeProxy_, address multiVault_) {
        feeProxy = feeProxy_;
        multiVault = multiVault_;
    }

    receive() external payable {
        revert("RevertingReceiverMock: reject");
    }

    /// @notice Approves the {FeeProxy} as a creation-side sender on
    ///         {MultiVault}, so the mock can be used as the `msg.sender` in
    ///         routing calls if needed.
    function grantCreationApproval() external {
        (bool ok,) =
            multiVault.call(abi.encodeWithSignature("approve(address,uint8)", feeProxy, uint8(ApprovalTypes.ALL)));
        require(ok, "approve failed");
    }
}

/// @notice Refund-flow mock that accepts every native ETH transfer in its
///         `receive`. Used to assert the push-success branch of
///         {FeeProxy._refundExcess}.
contract PayableReceiverMock {
    receive() external payable { }
}

/// @notice Shared scaffolding for the {FeeProxy} unit + fuzz suites.
///         Deploys a TUP-backed {FeeProxy}, wires it against the {MultiVault}
///         from {BaseTest}, and grants the proxy `ApprovalTypes.ALL` for every
///         test user so routing calls clear MultiVault's approval gate
///         transparently.
abstract contract FeeProxyBaseTest is BaseTest {
    /* =================================================== */
    /*                  PROTOCOL-LEVEL CAPS                */
    /* =================================================== */

    uint256 internal constant INITIAL_MAX_FEE_BPS = 2000; // 20%
    uint256 internal constant INITIAL_MAX_FIXED_FEE = 1 ether;
    uint256 internal constant INITIAL_REGISTRATION_FEE = 0.1 ether;

    /// @dev Storage slot of the `pendingRefund` mapping, pinned by the FeeProxy storage-layout
    ///      regression (matches `SLOT_PENDING_REFUND` in FeeProxyUpgradeRegression).
    uint256 internal constant PENDING_REFUND_SLOT = 6;

    /* =================================================== */
    /*                     SAMPLE CONFIG                   */
    /* =================================================== */

    uint256 internal constant SAMPLE_DEPOSIT_BPS = 100; // 1%
    uint256 internal constant SAMPLE_CREATION_BPS = 200; // 2%
    uint256 internal constant SAMPLE_DEPOSIT_FIXED_FEE = 0.001 ether;
    uint256 internal constant SAMPLE_CREATION_FIXED_FEE = 0.002 ether;

    /* =================================================== */
    /*                      ROLES / ACTORS                 */
    /* =================================================== */

    address payable internal feeProxyAdmin;
    address payable internal treasury;
    address payable internal affiliate;
    address payable internal affiliateFeeRecipient;

    /* =================================================== */
    /*                     DEPLOYED STATE                  */
    /* =================================================== */

    FeeProxy internal feeProxy;
    FeeProxy internal feeProxyImpl;
    TransparentUpgradeableProxy internal feeProxyProxy;

    uint256 internal CURVE_ID;

    function setUp() public virtual override {
        super.setUp();

        feeProxyAdmin = payable(makeAddr("feeProxyAdmin"));
        treasury = payable(makeAddr("treasury"));
        affiliate = payable(makeAddr("affiliate"));
        affiliateFeeRecipient = payable(makeAddr("affiliateFeeRecipient"));
        vm.deal(affiliate, 100 ether);
        vm.deal(feeProxyAdmin, 100 ether);

        feeProxyImpl = new FeeProxy();
        feeProxyProxy = new TransparentUpgradeableProxy(
            address(feeProxyImpl),
            users.admin,
            abi.encodeWithSelector(
                FeeProxy.initialize.selector,
                address(protocol.multiVault),
                treasury,
                feeProxyAdmin,
                INITIAL_MAX_FEE_BPS,
                INITIAL_MAX_FIXED_FEE,
                INITIAL_REGISTRATION_FEE
            )
        );
        feeProxy = FeeProxy(payable(address(feeProxyProxy)));

        vm.label(address(feeProxyImpl), "FeeProxyImpl");
        vm.label(address(feeProxyProxy), "FeeProxyProxy");
        vm.label(address(feeProxy), "FeeProxy");

        CURVE_ID = getDefaultCurveId();

        _grantProxyApprovalFromUsers();
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    function _grantProxyApprovalFromUsers() internal {
        _grantProxyApproval(users.alice);
        _grantProxyApproval(users.bob);
        _grantProxyApproval(users.charlie);
    }

    function _grantProxyApproval(address user) internal {
        vm.startPrank(user);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.ALL);
        vm.stopPrank();
    }

    function _sampleFeeConfig() internal pure returns (FeeConfig memory) {
        return FeeConfig({
            depositBps: SAMPLE_DEPOSIT_BPS,
            creationBps: SAMPLE_CREATION_BPS,
            depositFixedFee: SAMPLE_DEPOSIT_FIXED_FEE,
            creationFixedFee: SAMPLE_CREATION_FIXED_FEE
        });
    }

    function _zeroFeeConfig() internal pure returns (FeeConfig memory) {
        return FeeConfig({ depositBps: 0, creationBps: 0, depositFixedFee: 0, creationFixedFee: 0 });
    }

    function _looseFeeGuard() internal pure returns (FeeGuard memory) {
        return FeeGuard({ maxFeeBps: type(uint256).max, maxFixedFee: type(uint256).max });
    }

    function _registerSampleAffiliate() internal returns (FeeConfig memory fees) {
        fees = _sampleFeeConfig();
        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();
    }

    function _registerZeroFeeAffiliate() internal returns (FeeConfig memory fees) {
        fees = _zeroFeeConfig();
        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();
    }

    function _createAtomDirect(string memory data, address creator) internal returns (bytes32 atomId) {
        atomId = createSimpleAtom(data, ATOM_COST[0], creator);
        vm.stopPrank();
    }

    /// @dev Wrapper around {BaseTest.makeDeposit} that closes the prank started by the helper.
    function _makeDepositDirect(address depositor, address receiver, bytes32 termId, uint256 curveId, uint256 amount)
        internal
        returns (uint256 shares)
    {
        shares = makeDeposit(depositor, receiver, termId, curveId, amount, 0);
        vm.stopPrank();
    }

    function _toBytesArray(string memory a) internal pure returns (bytes[] memory arr) {
        arr = new bytes[](1);
        arr[0] = abi.encodePacked(a);
    }

    function _toUintArray(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    function _toBytes32Array(bytes32 a) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](1);
        arr[0] = a;
    }
}
