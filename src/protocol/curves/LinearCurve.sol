// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

/**
 * @title  LinearCurve
 * @author 0xIntuition
 * @notice A bonding curve model where share value increases linearly through pro-rata
 *         fee accumulation rather than supply-based pricing. Collected fees are distributed
 *         proportionally to holders, enabling steady, predictable value growth for
 *         low-volatility scenarios.
 */
contract LinearCurve is BaseCurve {
    using FixedPointMathLib for uint256;

    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @dev Maximum number of shares that can be handled by the curve
    uint256 public constant MAX_SHARES = type(uint256).max;

    /// @dev Maximum number of assets that can be handled by the curve
    uint256 public constant MAX_ASSETS = type(uint256).max;

    /// @dev Represents one share in 18 decimal format
    uint256 public constant ONE_SHARE = 1e18;

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

    /// @notice Initializes a new LinearCurve
    /// @param _name The name of the curve
    function initialize(string calldata _name) external initializer {
        __BaseCurve_init(_name);
    }

    /* =================================================== */
    /*                   BASECURVE FUNCTIONS               */
    /* =================================================== */

    /// @inheritdoc BaseCurve
    function maxShares() external pure override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external pure override returns (uint256) {
        return MAX_ASSETS;
    }

    /// @inheritdoc BaseCurve
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
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkDepositBounds(assets, totalAssets, MAX_ASSETS);
        shares = _convertToShares(assets, totalAssets, totalShares);
        _checkDepositOut(shares, totalShares, MAX_SHARES);
    }

    /// @inheritdoc BaseCurve
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
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkRedeem(shares, totalShares);
        assets = _convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
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
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkMintBounds(shares, totalShares, MAX_SHARES);
        assets = totalShares == 0 ? shares : shares.fullMulDivUp(totalAssets, totalShares);
        _checkMintOut(assets, totalAssets, MAX_ASSETS);
    }

    /// @inheritdoc BaseCurve
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkWithdraw(assets, totalAssets);
        shares = totalShares == 0 ? assets : assets.fullMulDivUp(totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkDepositBounds(assets, totalAssets, MAX_ASSETS);
        shares = _convertToShares(assets, totalAssets, totalShares);
        _checkDepositOut(shares, totalShares, MAX_SHARES);
    }

    /// @inheritdoc BaseCurve
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        pure
        override
        returns (uint256 assets)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        _checkRedeem(shares, totalShares);
        assets = _convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function currentPrice(uint256 totalShares, uint256 totalAssets)
        external
        pure
        override
        returns (uint256 sharePrice)
    {
        _checkCurveDomains(totalAssets, totalShares, MAX_ASSETS, MAX_SHARES);
        return _convertToAssets(ONE_SHARE, totalShares, totalAssets);
    }

    /* =================================================== */
    /*                    INTERNAL FUNCTIONS               */
    /* =================================================== */

    /// @dev Internal function to convert assets to shares without checks
    function _convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        internal
        pure
        returns (uint256 shares)
    {
        uint256 supply = totalShares;
        shares = supply == 0 ? assets : assets.fullMulDiv(supply, totalAssets);
    }

    /// @dev Internal function to convert shares to assets without checks
    function _convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        internal
        pure
        returns (uint256 assets)
    {
        uint256 supply = totalShares;
        assets = supply == 0 ? shares : shares.fullMulDiv(totalAssets, supply);
    }
}
