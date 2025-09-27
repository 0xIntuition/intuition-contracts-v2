// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

/**
 * @title  LinearCurve
 * @author 0xIntuition
 * @notice The price mechanism relies on fee accumulation rather than supply-based pricing.
 *         As fees are collected, they are distributed proportionally across all shareholders,
 *         creating gradual appreciation in share value. This provides a conservative
 *         incentivization model where early participants benefit from fee accumulation
 *         over time.
 *
 * @notice This implementation offers a low-volatility approach to value accrual,
 *         suitable for scenarios where predictable, steady returns are preferred
 *         over dynamic pricing mechanisms.
 */
contract LinearCurve is BaseCurve {
    using FixedPointMathLib for uint256;

    /// @dev Maximum number of shares that can be handled by the curve.
    uint256 public constant MAX_SHARES = type(uint256).max;

    /// @dev Maximum number of assets that can be handled by the curve.
    uint256 public constant MAX_ASSETS = type(uint256).max;

    /// @dev Represents one share in 18 decimal format
    uint256 public constant ONE_SHARE = 1e18;

    /// @notice Constructor for the Linear Curve.
    /// @param _name The name of the curve.
    constructor(string memory _name) BaseCurve(_name) { }

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
        return convertToShares(assets, totalAssets, totalShares);
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
        assets = convertToAssets(shares, totalShares, totalAssets);
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
        shares = convertToShares(assets, totalAssets, totalShares);
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
        assets = convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        public
        pure
        override
        returns (uint256 shares)
    {
        uint256 supply = totalShares;
        shares = supply == 0 ? assets : assets.mulDiv(supply, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        public
        pure
        override
        returns (uint256 assets)
    {
        uint256 supply = totalShares;
        assets = supply == 0 ? shares : shares.mulDiv(totalAssets, supply);
    }

    /// @inheritdoc BaseCurve
    function currentPrice(uint256 totalShares, uint256 totalAssets) public pure override returns (uint256 sharePrice) {
        return convertToAssets(ONE_SHARE, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function maxShares() external pure override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external pure override returns (uint256) {
        return MAX_ASSETS;
    }
}
