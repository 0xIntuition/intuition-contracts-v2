// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { ApprovalTypes, IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract MulticallFailureCatcher {
    IMultiVault internal immutable multiVault;
    uint256 internal immutable curveId;

    bytes4 public lastFailureSelector;

    constructor(IMultiVault multiVault_, uint256 curveId_) {
        multiVault = multiVault_;
        curveId = curveId_;
    }

    function catchFailedThenDeposit(bytes32 atomId) external payable returns (uint256 shares) {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.deposit, (address(this), atomId, curveId, 0));
        uint256[] memory values = new uint256[](1);

        (bool ok, bytes memory reason) = address(multiVault).call(abi.encodeCall(IMultiVault.multicall, (data, values)));
        require(!ok, "multicall should fail");
        lastFailureSelector = _selector(reason);

        shares = multiVault.deposit{ value: msg.value }(address(this), atomId, curveId, 0);
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length >= 4) {
            assembly {
                selector := mload(add(reason, 0x20))
            }
        }
    }
}

contract RedeemReentryReceiver {
    enum AttackMode {
        None,
        Deposit,
        Redeem,
        MulticallRedeem,
        MulticallDeposit,
        ApproveWithValue
    }

    IMultiVault internal immutable multiVault;
    bytes32 internal immutable termId;
    uint256 internal immutable curveId;

    AttackMode public attackMode;
    bool public attackAttempted;
    bool public attackSucceeded;
    bytes4 public lastRevertSelector;

    constructor(IMultiVault multiVault_, bytes32 termId_, uint256 curveId_) {
        multiVault = multiVault_;
        termId = termId_;
        curveId = curveId_;
    }

    receive() external payable {
        if (attackMode == AttackMode.None || attackAttempted) return;

        attackAttempted = true;

        if (attackMode == AttackMode.Deposit) {
            try multiVault.deposit(address(this), termId, curveId, 0) returns (uint256) {
                attackSucceeded = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        } else if (attackMode == AttackMode.Redeem) {
            try multiVault.redeem(address(this), termId, curveId, 1, 0) returns (uint256) {
                attackSucceeded = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        } else if (attackMode == AttackMode.MulticallRedeem) {
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encodeCall(IMultiVault.redeem, (address(this), termId, curveId, 1, 0));
            try multiVault.multicall(data, new uint256[](data.length)) returns (bytes[] memory) {
                attackSucceeded = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        } else if (attackMode == AttackMode.MulticallDeposit) {
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encodeCall(IMultiVault.deposit, (address(this), termId, curveId, 0));
            uint256[] memory values = new uint256[](1);
            try multiVault.multicall(data, values) returns (bytes[] memory) {
                attackSucceeded = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        } else if (attackMode == AttackMode.ApproveWithValue) {
            try multiVault.approve{ value: 1 wei }(address(0xBEEF), ApprovalTypes.DEPOSIT) {
                attackSucceeded = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        }
    }

    function seedDeposit() external payable returns (uint256 shares) {
        shares = multiVault.deposit{ value: msg.value }(address(this), termId, curveId, 0);
    }

    function redeemWithAttack(AttackMode mode, uint256 shares) external returns (uint256 assets) {
        attackMode = mode;
        attackAttempted = false;
        attackSucceeded = false;
        lastRevertSelector = bytes4(0);

        if (mode == AttackMode.ApproveWithValue) {
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encodeCall(IMultiVault.redeem, (address(this), termId, curveId, shares, 0));
            bytes[] memory results = multiVault.multicall(data, new uint256[](data.length));
            assets = abi.decode(results[0], (uint256));
        } else {
            assets = multiVault.redeem(address(this), termId, curveId, shares, 0);
        }
        attackMode = AttackMode.None;
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length >= 4) {
            assembly {
                selector := mload(add(reason, 0x20))
            }
        }
    }
}

contract TransientReentryTest is BaseTest {
    uint256 internal curveId;

    function setUp() public override {
        super.setUp();
        curveId = getDefaultCurveId();
    }

    function test_failedMulticallDoesNotLeakTransientStateIntoLaterCallInSameTx() external {
        bytes32 atomId = _createAtom("transient-catch", users.alice);
        MulticallFailureCatcher catcher =
            new MulticallFailureCatcher(IMultiVault(address(protocol.multiVault)), curveId);

        uint256 shares = catcher.catchFailedThenDeposit{ value: 2 ether }(atomId);

        assertEq(
            catcher.lastFailureSelector(),
            MultiVault.MultiVault_DepositBelowMinimumDeposit.selector,
            "caught revert is the zero-value subcall"
        );
        assertGt(shares, 0, "direct deposit after caught revert succeeds");
        assertEq(protocol.multiVault.getShares(address(catcher), atomId, curveId), shares, "shares credited once");
    }

    function test_redeemReceiverCannotReenterDeposit() external {
        _assertRedeemReentryBlocked(RedeemReentryReceiver.AttackMode.Deposit);
    }

    function test_redeemReceiverCannotReenterRedeem() external {
        _assertRedeemReentryBlocked(RedeemReentryReceiver.AttackMode.Redeem);
    }

    function test_redeemReceiverCannotReenterMulticallRedeem() external {
        _assertRedeemReentryBlocked(RedeemReentryReceiver.AttackMode.MulticallRedeem);
    }

    function test_redeemReceiverCannotReenterMulticallDeposit() external {
        _assertRedeemReentryBlocked(RedeemReentryReceiver.AttackMode.MulticallDeposit);
    }

    function test_redeemReceiverCannotReenterApproveWithValue() external {
        _assertRedeemReentryBlocked(RedeemReentryReceiver.AttackMode.ApproveWithValue);
    }

    function _assertRedeemReentryBlocked(RedeemReentryReceiver.AttackMode mode) internal {
        bytes32 atomId = _createAtom(string.concat("reentry-", _modeLabel(mode)), users.alice);
        RedeemReentryReceiver receiver =
            new RedeemReentryReceiver(IMultiVault(address(protocol.multiVault)), atomId, curveId);

        uint256 seededShares = receiver.seedDeposit{ value: 5 ether }();
        uint256 sharesToRedeem = seededShares / 2;
        uint256 sharesBefore = protocol.multiVault.getShares(address(receiver), atomId, curveId);
        uint256 vaultBalanceBefore = address(protocol.multiVault).balance;

        uint256 assets = receiver.redeemWithAttack(mode, sharesToRedeem);

        assertGt(assets, 0, "outer redeem succeeds");
        assertTrue(receiver.attackAttempted(), "receiver attempted reentry");
        assertFalse(receiver.attackSucceeded(), "nested action must fail");
        assertEq(
            receiver.lastRevertSelector(),
            ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector,
            "MultiVault nonReentrant guard blocks nested action"
        );
        assertEq(
            protocol.multiVault.getShares(address(receiver), atomId, curveId),
            sharesBefore - sharesToRedeem,
            "only outer redeem burns shares"
        );
        assertEq(
            address(protocol.multiVault).balance,
            vaultBalanceBefore - assets,
            "reentrant call cannot strand value in MultiVault"
        );
    }

    function _createAtom(string memory label, address creator) internal returns (bytes32 atomId) {
        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked(label);
        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;

        vm.startPrank(creator);
        bytes32[] memory ids = protocol.multiVault.createAtoms{ value: atomCost }(atomData, assets);
        vm.stopPrank();

        atomId = ids[0];
    }

    function _modeLabel(RedeemReentryReceiver.AttackMode mode) internal pure returns (string memory) {
        if (mode == RedeemReentryReceiver.AttackMode.Deposit) return "deposit";
        if (mode == RedeemReentryReceiver.AttackMode.Redeem) return "redeem";
        if (mode == RedeemReentryReceiver.AttackMode.MulticallRedeem) return "multicall-redeem";
        if (mode == RedeemReentryReceiver.AttackMode.MulticallDeposit) return "multicall-deposit";
        return "approve-with-value";
    }
}
