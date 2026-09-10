// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";

/// @title  MockFeeHookCurve
/// @notice Test-only hook curve: flat 1:1 pricing inherited from {LinearCurve} plus a fully
///         instrumented, unpermissioned fee-hook surface. Each hook path (deposit / redeem) can be
///         toggled independently and charges a settable flat bps fee, and every record call is
///         tallied with the value it received — isolating the MultiVault-side dispatch branches
///         from any real curve's economics or caller gating.
contract MockFeeHookCurve is LinearCurve {
    uint256 internal constant BPS = 10_000;

    bool public depositHookEnabled;
    bool public redeemHookEnabled;
    uint256 public depositFeeBps;
    uint256 public redeemFeeBps;

    uint256 public recordDepositCalls;
    uint256 public recordRedeemCalls;
    uint256 public lastDepositValue;
    uint256 public lastRedeemValue;
    bytes32 public lastTermId;
    address public lastAccount;
    uint256 public lastShares;

    /* ============ TEST KNOBS ============ */

    function setHooks(bool _depositHookEnabled, bool _redeemHookEnabled) external {
        depositHookEnabled = _depositHookEnabled;
        redeemHookEnabled = _redeemHookEnabled;
    }

    function setFees(uint256 _depositFeeBps, uint256 _redeemFeeBps) external {
        depositFeeBps = _depositFeeBps;
        redeemFeeBps = _redeemFeeBps;
    }

    /* ============ FEE HOOKS ============ */

    function hasDepositFeeHook() external view override returns (bool) {
        return depositHookEnabled;
    }

    function hasRedeemFeeHook() external view override returns (bool) {
        return redeemHookEnabled;
    }

    function quoteDepositFee(bytes32, uint256 baseAssets) external view override returns (uint256) {
        return (baseAssets * depositFeeBps) / BPS;
    }

    function quoteRedeemFee(bytes32, address, uint256 grossAssets) external view override returns (uint256) {
        return (grossAssets * redeemFeeBps) / BPS;
    }

    function recordDeposit(bytes32 termId, address account, uint256 shares) external payable override {
        recordDepositCalls++;
        lastDepositValue = msg.value;
        lastTermId = termId;
        lastAccount = account;
        lastShares = shares;
    }

    function recordRedeem(bytes32 termId, address account, uint256 shares) external payable override {
        recordRedeemCalls++;
        lastRedeemValue = msg.value;
        lastTermId = termId;
        lastAccount = account;
        lastShares = shares;
    }
}

/// @title  MockStateDependentFeeCurve
/// @notice Adversarial test-only hook curve whose fee quotes read MULTIVAULT vault state (which
///         mutates between the calculation and record phases of a deposit/redeem). Against a
///         re-quoting dispatcher this curve would receive a forwarded value different from the fee
///         netted from the user; against the quote-once/carry dispatcher the two are equal by
///         dataflow. Exists purely to pin that guarantee.
contract MockStateDependentFeeCurve is LinearCurve {
    /// @dev Fee = current vault totalAssets / FEE_DIVISOR — deliberately state-dependent.
    uint256 internal constant FEE_DIVISOR = 50;

    address public probedMultiVault;
    uint256 public probedCurveId;

    uint256 public lastDepositValue;
    uint256 public lastRedeemValue;

    function setProbe(address _multiVault, uint256 _curveId) external {
        probedMultiVault = _multiVault;
        probedCurveId = _curveId;
    }

    function _vaultTotalAssets(bytes32 termId) internal view returns (uint256 totalAssets) {
        (totalAssets,) = IMultiVaultVaultReader(probedMultiVault).getVault(termId, probedCurveId);
    }

    function hasDepositFeeHook() external view override returns (bool) {
        return true;
    }

    function hasRedeemFeeHook() external view override returns (bool) {
        return true;
    }

    function quoteDepositFee(bytes32 termId, uint256) external view override returns (uint256) {
        return _vaultTotalAssets(termId) / FEE_DIVISOR;
    }

    function quoteRedeemFee(bytes32 termId, address, uint256) external view override returns (uint256) {
        return _vaultTotalAssets(termId) / FEE_DIVISOR;
    }

    function recordDeposit(bytes32, address, uint256) external payable override {
        lastDepositValue = msg.value;
    }

    function recordRedeem(bytes32, address, uint256) external payable override {
        lastRedeemValue = msg.value;
    }
}

/// @dev Minimal reader interface so the mock can probe MultiVault vault totals.
interface IMultiVaultVaultReader {
    function getVault(bytes32 termId, uint256 curveId) external view returns (uint256, uint256);
}
