// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { UD60x18, wrap, unwrap, uUNIT } from "@prb/math/src/UD60x18.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

/**
 * @title  ProgressiveCurve
 * @author 0xIntuition
 * @notice A bonding curve implementation that uses a progressive pricing model where
 *         each new share costs more than the last.
 *
 *         The price follows the formula:
 *         $$P(s) = m \cdot s$$
 *         where:
 *         - $m$ is the slope (in basis points)
 *         - $s$ is the total supply of shares
 *
 *         The cost to mint shares is calculated as the area under this curve:
 *         $$\text{Cost} = (s_2^2 - s_1^2) \cdot \frac{m}{2}$$
 *         where $s_1$ is the starting share supply and $s_2$ is the final share supply.
 *
 *         This curve creates stronger incentives for early stakers compared to the LinearCurve,
 *         while maintaining fee-based appreciation.
 *
 * @dev    Uses the prb-math library for fixed point arithmetic with UD60x18
 * @dev    Fixed point precision used for all internal calculations, while return values are all
 *             represented as regular uint256s, and unwrapped.  I.e. we might use 123.456 internally
 *             and return 123.
 * @dev    The core equation:
 *             $$P(s) = m \cdot s$$
 *             and the cost equation:
 *             $$\text{Cost} = (s_2^2 - s_1^2) \cdot \frac{m}{2}$$
 *             comes from calculus - it's the integral of a linear price function. The area under a
 *             linear curve from point $s_1$ to $s_2$ gives us the total cost/return of minting/redeeming
 *             shares.
 * @dev    Inspired by the Solaxy.sol contract: https://github.com/M3tering/Solaxy/blob/main/src/Solaxy.sol
 *          and https://m3tering.whynotswitch.com/token-economics/mint-and-distribution.  * The key difference
 *          between the Solaxy contract and this one is that the economic state is handled by the MMultiVault
 *          instead of directly in the curve implementation. *  Otherwise the math is identical.
 */
contract ProgressiveCurve is BaseCurve {
    /// @notice The slope of the curve, in basis points.  This is the rate at which the price of shares increases.
    /// @dev 0.0025e18 -> 25 basis points, 0.0001e18 = 1 basis point, etc etc
    /// @dev If minDeposit is 0.003 ether, this value would need to be 0.00007054e18 to avoid returning 0 shares for
    /// minDeposit assets
    UD60x18 public SLOPE;

    /// @notice The half of the slope, used for calculations.
    UD60x18 public HALF_SLOPE;

    /// @dev Since powu(2) will overflow first (see slope equation), maximum totalShares is sqrt(MAX_UD60x18)
    uint256 public MAX_SHARES;

    /// @dev The maximum assets is totalShares * slope / 2, because multiplication (see slope equation) would overflow
    /// beyond that point.
    uint256 public MAX_ASSETS;

    /// @notice Custom errors
    error ProgressiveCurve_InvalidSlope();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes a new ProgressiveCurve with the given name and slope
    /// @param _name The name of the curve (i.e. "Progressive Curve #465")
    /// @param slope18 The slope of the curve, in basis points (i.e. 0.0025e18)
    /// @dev Computes maximum values given constructor arguments
    /// @dev Computes Slope / 2 as commonly used constant
    function initialize(string calldata _name, uint256 slope18) external initializer {
        __BaseCurve_init(_name);

        if (slope18 == 0 || slope18 % 2 != 0) revert ProgressiveCurve_InvalidSlope();

        SLOPE = wrap(slope18);
        HALF_SLOPE = wrap(slope18 / 2);

        uint256 r = FixedPointMathLib.sqrt(type(uint256).max / 1e18);
        MAX_SHARES = r;

        // MAX_ASSETS = (r^2) * (m/2), rounded DOWN
        UD60x18 sMax = wrap(r);
        UD60x18 aMax = _square(sMax).mul(HALF_SLOPE); // mul (down)
        MAX_ASSETS = unwrap(aMax);
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply
    /// @dev Let $a$ = amount of assets to deposit
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev shares:
    /// $$\text{shares} = \sqrt{s^2 + \frac{a}{m/2}} - s$$
    /// @dev or to say that another way:
    /// $$\text{shares} = \sqrt{s^2 + \frac{2a}{m}} - s$$
    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        override
        returns (uint256 shares)
    {
        _checkDepositBounds(assets, totalAssets, MAX_ASSETS);

        UD60x18 s = wrap(totalShares);
        UD60x18 inner = _square(s).add(wrap(assets).div(HALF_SLOPE)); // div down
        UD60x18 out = inner.sqrt().sub(s); // sqrt down
        shares = unwrap(out); // down

        _checkDepositOut(shares, totalShares, MAX_SHARES);
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = initial total supply of shares
    /// @dev Let $r$ = shares to redeem
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev assets:
    /// $$\text{assets} = (s^2 - (s-r)^2) \cdot \frac{m}{2}$$
    /// @dev this can be expanded to:
    /// $$\text{assets} = (s^2 - (s^2 - 2sr + r^2)) \cdot \frac{m}{2}$$
    /// @dev which simplifies to:
    /// $$\text{assets} = (2sr - r^2) \cdot \frac{m}{2}$$
    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 /*totalAssets*/
    )
        public
        view
        override
        returns (uint256 assets)
    {
        _checkRedeem(shares, totalShares);

        UD60x18 s = wrap(totalShares);
        UD60x18 ns = s.sub(wrap(shares));

        UD60x18 area = _square(s).sub(_squareUp(ns)); // A down - B up
        UD60x18 assetsUD = area.mul(HALF_SLOPE); // mul down
        assets = unwrap(assetsUD); // down
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $n$ = new shares to mint
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev assets:
    /// $$\text{assets} = ((s + n)^2 - s^2) \cdot \frac{m}{2}$$
    /// @dev which can be expanded to:
    /// $$\text{assets} = (s^2 + 2sn + n^2 - s^2) \cdot \frac{m}{2}$$
    /// @dev which simplifies to:
    /// $$\text{assets} = (2sn + n^2) \cdot \frac{m}{2}$$
    function previewMint(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        override
        returns (uint256 assets)
    {
        _checkMintBounds(shares, totalShares, MAX_SHARES);

        UD60x18 s0 = wrap(totalShares);
        UD60x18 s1 = wrap(totalShares + shares);

        UD60x18 area = _squareUp(s1).sub(_square(s0)); // A up - B down
        UD60x18 aUD = _mulUp(area, HALF_SLOPE); // mul up
        assets = unwrap(aUD); // up

        _checkMintOut(assets, totalAssets, MAX_ASSETS);
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $a$ = assets to withdraw
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev shares:
    /// $$\text{shares} = s - \sqrt{s^2 - \frac{a}{m/2}}$$
    /// @dev or to say that another way:
    /// $$\text{shares} = s - \sqrt{s^2 - \frac{2a}{m}}$$
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        override
        returns (uint256 shares)
    {
        _checkWithdraw(assets, totalAssets);

        UD60x18 s = wrap(totalShares);
        UD60x18 deduct = _divUp(wrap(assets), HALF_SLOPE); // up (because it’s subtracted)
        UD60x18 inner = _square(s).sub(deduct);
        UD60x18 out = s.sub(inner.sqrt()); // sqrt down → result up

        shares = unwrap(out); // up
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $m$ = the slope of the curve
    /// @dev sharePrice:
    /// $$\text{sharePrice} = s \cdot m$$
    /// @dev This is the basic linear price function where the price increases linearly with the total supply
    /// @dev And the slope ($m$) determines how quickly the price increases
    /// @dev TLDR: Each new share costs more than the last
    function currentPrice(
        uint256 totalShares,
        uint256 /* totalAssets */
    )
        public
        view
        override
        returns (uint256 sharePrice)
    {
        return unwrap(wrap(totalShares).mul(SLOPE));
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $a$ = assets to convert to shares
    /// @dev Let $\frac{m}{2}$ = half of the slope
    /// @dev shares:
    /// $$\text{shares} = \frac{a}{s \cdot m/2}$$
    /// @dev Or to say that another way:
    /// $$\text{shares} = \frac{2a}{s \cdot m}$$
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        override
        returns (uint256 shares)
    {
        // Same as previewDeposit
        return this.previewDeposit(assets, totalAssets, totalShares);
    }

    /// @inheritdoc BaseCurve
    /// @dev Let $s$ = current total supply of shares
    /// @dev Let $n$ = quantity of shares to convert to assets
    /// @dev conversion price:
    /// $$\text{price} = s \cdot \frac{m}{2}$$
    /// @dev where $\frac{m}{2}$ is average price per share
    /// @dev assets:
    /// $$\text{assets} = n \cdot (s \cdot \frac{m}{2})$$
    /// @dev Or to say that another way:
    /// $$\text{assets} = n \cdot s \cdot \frac{m}{2}$$
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 /*totalAssets*/
    )
        external
        view
        override
        returns (uint256 assets)
    {
        // Same as previewRedeem
        return this.previewRedeem(shares, totalShares, 0);
    }

    /// @inheritdoc BaseCurve
    function maxShares() external view override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external view override returns (uint256) {
        return MAX_ASSETS;
    }

    /**
     * @notice Computes assets as the area under a linear curve with a simplified form of the area of a trapezium:
     * $$f(x) = mx + c$$
     * $$\text{Area} = \frac{1}{2} \cdot (a + b) \cdot h$$
     * where $a$ and $b$ can be both $f(\text{juniorSupply})$ or $f(\text{seniorSupply})$ depending if used in minting
     * or redeeming.
     * Calculates area as:
     * $$(\text{seniorSupply}^2 - \text{juniorSupply}^2) \cdot \text{halfSlope}$$
     * where:
     * $$\text{halfSlope} = \frac{\text{slope}}{2}$$
     *
     * @param juniorSupply The smaller supply in the operation (the initial supply during mint,
     * or the final supply during a redeem operation).
     * @param seniorSupply The larger supply in the operation (the final supply during mint,
     * or the initial supply during a redeem operation).
     * @return assets The computed assets as an instance of UD60x18 (a fixed-point number).
     */
    function _convertToAssets(UD60x18 juniorSupply, UD60x18 seniorSupply) internal view returns (UD60x18 assets) {
        UD60x18 sqrDiff = _square(seniorSupply).sub(_square(juniorSupply));
        return sqrDiff.mul(HALF_SLOPE);
    }

    /// @dev Rounding helpers for UD60x18 operations
    function _mulUp(UD60x18 x, UD60x18 y) internal pure returns (UD60x18) {
        uint256 r = FixedPointMathLib.fullMulDivUp(unwrap(x), unwrap(y), uUNIT);
        return wrap(r);
    }

    function _divUp(UD60x18 x, UD60x18 y) internal pure returns (UD60x18) {
        uint256 r = FixedPointMathLib.fullMulDivUp(unwrap(x), uUNIT, unwrap(y));
        return wrap(r);
    }

    function _square(UD60x18 x) internal pure returns (UD60x18) {
        // rounds down (like UD mul)
        return x.mul(x);
    }

    function _squareUp(UD60x18 x) internal pure returns (UD60x18) {
        return _mulUp(x, x);
    }
}
