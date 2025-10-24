// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { UD60x18, wrap, unwrap, add, sub, mul, div, sqrt, uUNIT, uMAX_UD60x18 } from "@prb/math/src/UD60x18.sol";

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";
import { ProgressiveCurveMathLib as PCMath } from "src/libraries/ProgressiveCurveMathLib.sol";

/**
 * @title  ProgressiveCurve
 * @author 0xIntuition
 * @notice A bonding curve implementation that uses a progressive pricing model where
 *         each new share costs more than the last.
 */
contract ProgressiveCurve is BaseCurve {
    /* =================================================== */
    /*                     STATE                           */
    /* =================================================== */

    /// @notice The slope of the curve (18 decimal fixed-point multiplier). This is the rate at which the price of
    /// shares increases
    UD60x18 public SLOPE;

    /// @notice The half of the slope, used for calculations
    UD60x18 public HALF_SLOPE;

    /// @dev The maximum shares are sqrt(uint256.max / 1e18) to prevent overflow in calculations
    uint256 public MAX_SHARES;

    /// @dev The maximum assets are derived from the maximum shares and slope to prevent overflow in calculations
    uint256 public MAX_ASSETS;

    /* =================================================== */
    /*                     ERRORS                          */
    /* =================================================== */

    /// @notice Custom errors
    error ProgressiveCurve_InvalidSlope();

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializes a new ProgressiveCurve with the given name and slope
    /// @dev Computes maximum values given constructor arguments
    /// @param _name The name of the curve
    /// @param slope18 The slope of the curve, in 18 decimal fixed-point format
    function initialize(string calldata _name, uint256 slope18) external initializer {
        __BaseCurve_init(_name);

        if (slope18 == 0 || slope18 % 2 != 0) revert ProgressiveCurve_InvalidSlope();

        SLOPE = wrap(slope18);
        HALF_SLOPE = wrap(slope18 / 2);

        UD60x18 maxSharesUD = sqrt(wrap(uMAX_UD60x18 / uUNIT));
        UD60x18 maxAssetsUD = mul(PCMath.square(maxSharesUD), HALF_SLOPE);

        MAX_SHARES = unwrap(maxSharesUD);
        MAX_ASSETS = unwrap(maxAssetsUD);
    }

    /* =================================================== */
    /*                   BASECURVE FUNCTIONS               */
    /* =================================================== */

    /// @inheritdoc BaseCurve
    function maxShares() external view override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external view override returns (uint256) {
        return MAX_ASSETS;
    }

    /// @inheritdoc BaseCurve
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
        shares = _convertToShares(assets, totalAssets, totalShares);
    }

    /// @inheritdoc BaseCurve
    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        override
        returns (uint256 assets)
    {
        assets = _convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
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
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkMintBounds(shares, totalShares, MAX_SHARES);

        UD60x18 s = wrap(totalShares);
        UD60x18 sNext = add(s, wrap(shares));

        UD60x18 area = sub(PCMath.squareUp(sNext), (PCMath.square(s)));
        UD60x18 assetsUD = PCMath.mulUp(area, HALF_SLOPE);
        assets = unwrap(assetsUD);

        _checkMintOut(assets, totalAssets, MAX_ASSETS);
    }

    /// @inheritdoc BaseCurve
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
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkWithdraw(assets, totalAssets);

        UD60x18 s = wrap(totalShares);
        UD60x18 deduct = PCMath.divUp(wrap(assets), HALF_SLOPE);

        UD60x18 inner = sub(PCMath.square(s), deduct);
        UD60x18 sharesUD = sub(s, sqrt(inner));
        shares = unwrap(sharesUD);
    }

    /// @inheritdoc BaseCurve
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
        shares = _convertToShares(assets, totalAssets, totalShares);
    }

    /// @inheritdoc BaseCurve
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        override
        returns (uint256 assets)
    {
        assets = _convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function currentPrice(
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        override
        returns (uint256 sharePrice)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        return unwrap(mul(wrap(totalShares), SLOPE));
    }

    /* =================================================== */
    /*                    INTERNAL FUNCTIONS               */
    /* =================================================== */

    /// @dev Internal function to convert assets to shares
    function _convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        internal
        view
        returns (uint256 shares)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkDepositBounds(assets, totalAssets, MAX_ASSETS);

        UD60x18 s = wrap(totalShares);
        UD60x18 inner = add(PCMath.square(s), div(wrap(assets), HALF_SLOPE));
        UD60x18 sharesUD = sub(sqrt(inner), s);
        shares = unwrap(sharesUD);

        _checkDepositOut(shares, totalShares, MAX_SHARES);
    }

    /// @dev Internal function to convert shares to assets
    function _convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        internal
        view
        returns (uint256 assets)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkRedeem(shares, totalShares);

        UD60x18 s = wrap(totalShares);
        UD60x18 sNext = sub(s, wrap(shares));

        UD60x18 area = sub(PCMath.square(s), (PCMath.squareUp(sNext)));
        UD60x18 assetsUD = mul(area, HALF_SLOPE);
        assets = unwrap(assetsUD);
    }
}
