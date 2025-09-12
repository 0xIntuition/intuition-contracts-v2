// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

/**
 * Pump.fun-style bonding curve (scaled):
 *   Internal curve:
 *     y = V - K / (C + x), with C = 30e18 (exact Pump.fun)
 *     V = 1,073,000,191e18 tokens
 *     K = 32,190,005,730 * 1e36  (keeps WAD throughout)
 *
 *   External scaling:
 *     - TRUST (assets):   external -> internal by / 100_000
 *     - Tokens (shares):  internal -> external by * 100_000
 *
 *   This preserves the original shape up to 1B external TRUST
 *   and ~107.3000191T external tokens minted via the curve.
 */
contract PumpCurve is BaseCurve {
    // ---------- Constants ----------
    uint256 public constant SCALING_FACTOR = 100_000;

    // Internal (original) curve constants
    uint256 public constant VIRTUAL_TOKEN_RESERVES = 1_073_000_191 * 1e18; // V
    uint256 public constant VIRTUAL_TRUST_RESERVES_INTERNAL = 30 * 1e18; // C = 30e18
    uint256 public constant CURVE_NUMERATOR = 32_190_005_730 * 1e18 * 1e18; // K

    // External maxima:
    uint256 public constant MAX_ASSETS = 1_000_000_000 * 1e18; // 1B TRUST (external)
    uint256 public constant MAX_ASSETS_INTERNAL = 10_000 * 1e18; // 10k TRUST (internal)

    // Max tokens the curve can ever mint externally = V * SCALING_FACTOR
    // = 1_073_000_191 * 100_000 = 107_300_019_100_000
    uint256 public constant MAX_SHARES = 107_300_019_100_000 * 1e18; // 107.3000191T

    // Optional UI/UX helpers; keep or adjust as your product needs
    uint256 public constant RESERVED_TOKENS = 20_690_000_000_000 * 1e18; // 20.69T
    uint256 public constant INITIAL_REAL_TOKEN_RESERVES = 79_310_000_000_000 * 1e18; // 79.31T

    constructor(string memory _name) BaseCurve(_name) { }

    // ---------- BaseCurve overrides ----------

    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        require(totalAssets + assets <= MAX_ASSETS, "Exceeds max assets");

        // External -> internal
        uint256 a = _scaleDownAssets(assets);
        uint256 A = _scaleDownAssets(totalAssets);

        // Tokens before/after (internal tokens)
        uint256 tBefore = _tokensFromFormula(A);
        uint256 tAfter = _tokensFromFormula(A + a);

        // Minted internal tokens, then scale to external
        uint256 mintedInternal = tAfter - tBefore;
        uint256 mintedExternal = _scaleUpTokens(mintedInternal);

        // Respect the external cap using provided totalShares
        if (totalShares + mintedExternal > MAX_SHARES) {
            mintedExternal = MAX_SHARES - totalShares;
        }
        return mintedExternal;
    }

    function previewMint(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        pure
        override
        returns (uint256 assets)
    {
        // Bound to cap
        require(totalShares + shares <= MAX_SHARES, "Exceeds max shares");

        // External -> internal
        uint256 s = _scaleDownTokens(shares);
        uint256 S = _scaleDownTokens(totalShares);
        uint256 A = _scaleDownAssets(totalAssets);

        // Target internal tokens after mint
        uint256 targetTokens = S + s;
        require(targetTokens < VIRTUAL_TOKEN_RESERVES, "At curve limit");

        // x = K / (V - y) - C, where y = targetTokens and (V - y) is remainingTokens
        uint256 remainingTokens = VIRTUAL_TOKEN_RESERVES - targetTokens;
        uint256 reqInternal = _trustFromRemainingTokens(remainingTokens);

        // Additional internal trust required
        uint256 needInternal = reqInternal > A ? (reqInternal - A) : 0;
        return _scaleUpAssets(needInternal);
    }

    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 /* totalShares */
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        require(assets <= totalAssets, "Insufficient assets");

        uint256 a = _scaleDownAssets(assets);
        uint256 A = _scaleDownAssets(totalAssets);

        uint256 tBefore = _tokensFromFormula(A);
        uint256 tAfter = _tokensFromFormula(A - a);

        // Burn = before - after (internal → external)
        return _scaleUpTokens(tBefore - tAfter);
    }

    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        pure
        override
        returns (uint256 assets)
    {
        require(shares <= totalShares, "Insufficient shares");

        uint256 s = _scaleDownTokens(shares);
        uint256 S = _scaleDownTokens(totalShares);
        uint256 A = _scaleDownAssets(totalAssets);

        // Move to lower token level, compute released internal TRUST
        uint256 newS = S - s;
        uint256 remainingTokens = VIRTUAL_TOKEN_RESERVES - newS;
        uint256 xAfter = _trustFromRemainingTokens(remainingTokens);

        uint256 releasedInternal = A > xAfter ? (A - xAfter) : 0;
        return _scaleUpAssets(releasedInternal);
    }

    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        public
        view
        override
        returns (uint256)
    {
        return this.previewDeposit(assets, totalAssets, totalShares);
    }

    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        public
        view
        override
        returns (uint256)
    {
        return this.previewRedeem(shares, totalShares, totalAssets);
    }

    /// @notice Marginal price (TRUST per token) at `totalShares`
    function currentPrice(uint256 totalShares) public pure override returns (uint256) {
        uint256 S = _scaleDownTokens(totalShares);
        if (S >= VIRTUAL_TOKEN_RESERVES) return 0;

        uint256 rem = VIRTUAL_TOKEN_RESERVES - S;
        if (rem <= 1e18) return type(uint256).max / 1e18;

        // Finite difference in internal space: Δx for Δy = 1e18 internal token
        uint256 xNow = _trustFromRemainingTokens(rem);
        uint256 xNext = _trustFromRemainingTokens(rem - 1e18);
        // Using ceil on xNext avoids rare 1-wei dips in fuzzing
        return xNext > xNow ? (xNext - xNow) : 0;
    }

    function maxShares() external pure override returns (uint256) {
        return MAX_SHARES;
    }

    function maxAssets() external pure override returns (uint256) {
        return MAX_ASSETS;
    }

    function bondingCurveProgress(uint256 totalShares) external pure returns (uint256) {
        if (totalShares >= INITIAL_REAL_TOKEN_RESERVES) return 100;
        return (totalShares * 100) / INITIAL_REAL_TOKEN_RESERVES;
    }

    function isCurveComplete(uint256 totalShares) external pure returns (bool) {
        return totalShares >= INITIAL_REAL_TOKEN_RESERVES;
    }

    // ---------- Internal math (all WAD) ----------

    /// y = V - K / (C + x)
    function _tokensFromFormula(uint256 trustAmount) internal pure returns (uint256) {
        if (trustAmount > MAX_ASSETS_INTERNAL) trustAmount = MAX_ASSETS_INTERNAL;
        uint256 denom = VIRTUAL_TRUST_RESERVES_INTERNAL + trustAmount; // C + x
        uint256 frac = CURVE_NUMERATOR / denom;
        return VIRTUAL_TOKEN_RESERVES > frac ? (VIRTUAL_TOKEN_RESERVES - frac) : 0;
    }

    /// x = K / (V - y) - C   where `remainingTokens = V - y`
    function _trustFromRemainingTokens(uint256 remainingTokens) internal pure returns (uint256) {
        if (remainingTokens == 0) return MAX_ASSETS_INTERNAL; // avoid div-by-zero
        if (remainingTokens >= VIRTUAL_TOKEN_RESERVES) return 0; // y = 0 → x = 0

        uint256 q = CURVE_NUMERATOR / remainingTokens; // K / (V - y)
        return q > VIRTUAL_TRUST_RESERVES_INTERNAL ? (q - VIRTUAL_TRUST_RESERVES_INTERNAL) : 0;
    }

    function _initialPrice() internal pure returns (uint256) {
        // d/dx[V - K/(C+x)] at x=0 -> K / C^2
        uint256 denom = VIRTUAL_TRUST_RESERVES_INTERNAL * VIRTUAL_TRUST_RESERVES_INTERNAL; // C^2
        return CURVE_NUMERATOR / denom; // WAD
    }

    // ---------- Scaling helpers ----------
    function _scaleDownAssets(uint256 externalAmount) internal pure returns (uint256) {
        return externalAmount / SCALING_FACTOR;
    }

    function _scaleUpAssets(uint256 internalAmount) internal pure returns (uint256) {
        return internalAmount * SCALING_FACTOR;
    }

    function _scaleDownTokens(uint256 externalTokens) internal pure returns (uint256) {
        return externalTokens / SCALING_FACTOR;
    }

    function _scaleUpTokens(uint256 internalTokens) internal pure returns (uint256) {
        return internalTokens * SCALING_FACTOR;
    }
}
